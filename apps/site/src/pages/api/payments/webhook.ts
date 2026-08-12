import type { NextApiRequest, NextApiResponse } from 'next';
import { getPaymentStatus, isValidWebhookSignature } from '@/lib/payments';
import { isSupabaseConfigured } from '@/config/env';
import { getSupabaseAdminClient } from '@/lib/supabaseClient';
import { env } from '@/config/env';

/**
 * POST /api/payments/webhook
 * Endpoint de notificação (IPN) do Mercado Pago.
 * Configurar esta URL em: https://www.mercadopago.com.br/developers/panel/notifications
 */
export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  if (req.method !== 'POST') {
    res.setHeader('Allow', 'POST');
    return res.status(405).end();
  }

  if (!isValidWebhookSignature(req.headers)) {
    return res.status(401).json({ error: 'Assinatura inválida' });
  }

  try {
    const paymentId: string | undefined = req.query['data.id'] as string | undefined || req.body?.data?.id;
    if (!paymentId) {
      // Mercado Pago também envia notificações de teste sem payment id — responder 200 para não gerar retry infinito.
      return res.status(200).json({ ok: true, ignored: true });
    }

    const payment = await getPaymentStatus(paymentId);

    if (isSupabaseConfigured && payment.externalReference) {
      const admin = getSupabaseAdminClient();

      await admin.from('payments').insert({
        order_id: payment.externalReference,
        gateway: 'mercado_pago',
        status: payment.status,
        transaction_id: String(payment.id),
        payload: payment,
      });

      const orderStatus =
        payment.status === 'approved' ? 'pago' : payment.status === 'rejected' ? 'recusado' : 'pendente';

      await admin.from('orders').update({ status: orderStatus }).eq('id', payment.externalReference);

      if (orderStatus === 'pago') {
        // Dispara automação n8n: liberar matrícula, enviar certificado, notificar aluno, etc.
        if (env.n8n.baseUrl) {
          fetch(`${env.n8n.baseUrl}/webhook/pagamento-aprovado`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ orderId: payment.externalReference }),
          }).catch(() => undefined);
        }
      }
    }

    return res.status(200).json({ ok: true });
  } catch (err) {
    console.error('[api/payments/webhook] erro ao processar notificação', err);
    // Retornar 200 evita reenvio agressivo do Mercado Pago em caso de erro não recuperável;
    // o erro fica registrado no log do servidor para investigação.
    return res.status(200).json({ ok: false });
  }
}
