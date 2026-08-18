import type { NextApiRequest, NextApiResponse } from 'next';
import { env, isMercadoPagoEnabled, isSupabaseConfigured } from '@/config/env';
import { getPaymentStatus, isValidWebhookSignature } from '@/lib/payments';
import { getSupabaseAdminClient } from '@/lib/supabaseClient';

function firstString(value: string | string[] | undefined): string | undefined {
  return Array.isArray(value) ? value[0] : value;
}

function mapOrderStatus(paymentStatus: string | null | undefined) {
  if (paymentStatus === 'approved') return 'pago';
  if (paymentStatus === 'rejected' || paymentStatus === 'cancelled') return 'recusado';
  return 'pendente';
}

/** POST /api/payments/webhook — Webhook assinado do Mercado Pago. */
export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  if (req.method !== 'POST') {
    res.setHeader('Allow', 'POST');
    return res.status(405).end();
  }
  if (!isMercadoPagoEnabled || !isSupabaseConfigured) {
    return res.status(503).json({ error: 'Pagamentos indisponíveis neste ambiente' });
  }

  const paymentId =
    firstString(req.query['data.id'] as string | string[] | undefined) ??
    (typeof req.body?.data?.id === 'string' ? req.body.data.id : undefined);
  if (!paymentId) {
    return res.status(400).json({ error: 'Identificador do pagamento ausente' });
  }
  if (!isValidWebhookSignature(req.headers, paymentId)) {
    return res.status(401).json({ error: 'Assinatura inválida' });
  }

  try {
    const payment = await getPaymentStatus(paymentId);
    if (!payment.id || !payment.externalReference || !payment.status) {
      throw new Error('Pagamento sem referência externa ou estado');
    }

    const admin = getSupabaseAdminClient();
    const { data: order, error: orderError } = await admin
      .from('orders')
      .select('id, total, status')
      .eq('id', payment.externalReference)
      .single();
    if (orderError || !order) throw new Error('Pedido associado não encontrado');

    if (payment.transactionAmount !== undefined && payment.transactionAmount !== null) {
      const expectedCents = Math.round(Number(order.total) * 100);
      const paidCents = Math.round(Number(payment.transactionAmount) * 100);
      if (!Number.isFinite(paidCents) || paidCents !== expectedCents) {
        throw new Error('Valor do pagamento diverge do pedido');
      }
    }

    const transactionId = String(payment.id);
    const { data: paymentRecord, error: paymentError } = await admin
      .from('payments')
      .upsert(
        {
          order_id: order.id,
          gateway: 'mercado_pago',
          status: payment.status,
          transaction_id: transactionId,
          payload: payment,
        },
        { onConflict: 'gateway,transaction_id' },
      )
      .select('id, automation_notified_at')
      .single();
    if (paymentError || !paymentRecord) throw paymentError ?? new Error('Pagamento não persistido');

    const nextOrderStatus = mapOrderStatus(payment.status);
    if (order.status !== 'pago' || nextOrderStatus === 'pago') {
      const { error: updateError } = await admin
        .from('orders')
        .update({ status: nextOrderStatus })
        .eq('id', order.id);
      if (updateError) throw updateError;
    }

    if (nextOrderStatus === 'pago' && env.n8n.baseUrl && !paymentRecord.automation_notified_at) {
      const response = await fetch(`${env.n8n.baseUrl}/webhook/pagamento-aprovado`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          ...(env.n8n.webhookToken ? { Authorization: `Bearer ${env.n8n.webhookToken}` } : {}),
          'Idempotency-Key': `mercado-pago:${transactionId}`,
        },
        body: JSON.stringify({ orderId: order.id, transactionId }),
        signal: AbortSignal.timeout(8_000),
      });
      if (!response.ok) throw new Error(`Automação n8n recusou o evento: HTTP ${response.status}`);

      const { error: notifiedError } = await admin
        .from('payments')
        .update({ automation_notified_at: new Date().toISOString() })
        .eq('id', paymentRecord.id);
      if (notifiedError) throw notifiedError;
    }

    return res.status(200).json({ ok: true });
  } catch (error) {
    console.error('[api/payments/webhook] erro ao processar notificação', error);
    return res.status(500).json({ ok: false });
  }
}
