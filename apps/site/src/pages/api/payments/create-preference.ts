import type { NextApiRequest, NextApiResponse } from 'next';
import { createPaymentPreference } from '@/lib/payments';
import { isSupabaseConfigured } from '@/config/env';
import { getSupabaseAdminClient } from '@/lib/supabaseClient';

interface CreatePreferenceBody {
  userId?: string;
  payerEmail?: string;
  items: { id: string; title: string; quantity: number; unitPrice: number }[];
}

/**
 * POST /api/payments/create-preference
 * Cria um pedido (orders/order_items) e uma preferência de pagamento no
 * Mercado Pago, retornando a URL de checkout para o front-end redirecionar.
 */
export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  if (req.method !== 'POST') {
    res.setHeader('Allow', 'POST');
    return res.status(405).json({ error: 'Método não permitido' });
  }

  const body = req.body as CreatePreferenceBody;
  if (!body?.items || body.items.length === 0) {
    return res.status(400).json({ error: 'Nenhum item informado' });
  }

  try {
    const total = body.items.reduce((sum, i) => sum + i.unitPrice * i.quantity, 0);
    let orderId = `local-${Date.now()}`;

    if (isSupabaseConfigured) {
      const admin = getSupabaseAdminClient();

      // orders.tenant_id é NOT NULL desde a migration multi-tenant (0002). O
      // checkout de apps/site vende produtos/cursos do próprio ConnectionCyber
      // (não é uma compra em nome de um tenant cliente), então o pedido
      // sempre pertence ao tenant "connectioncyber" — nunca vem do cliente.
      const { data: tenant, error: tenantError } = await admin
        .from('tenants')
        .select('id')
        .eq('slug', 'connectioncyber')
        .single();
      if (tenantError || !tenant) {
        throw new Error('Tenant connectioncyber não encontrado — não é possível registrar o pedido');
      }

      const { data: order, error: orderError } = await admin
        .from('orders')
        .insert({ user_id: body.userId ?? null, tenant_id: tenant.id, total, status: 'pendente' })
        .select('id')
        .single();

      if (orderError) throw orderError;
      orderId = order.id;

      const orderItems = body.items.map((item) => ({
        order_id: orderId,
        product_id: item.id,
        quantidade: item.quantity,
        preco_unitario: item.unitPrice,
      }));
      const { error: itemsError } = await admin.from('order_items').insert(orderItems);
      if (itemsError) throw itemsError;
    }

    const preference = await createPaymentPreference({
      orderId,
      items: body.items.map((i) => ({
        id: i.id,
        title: i.title,
        quantity: i.quantity,
        unitPrice: i.unitPrice,
      })),
      payerEmail: body.payerEmail,
    });

    return res.status(200).json({ orderId, ...preference });
  } catch (err) {
    console.error('[api/payments/create-preference] erro', err);
    return res.status(500).json({ error: 'Não foi possível criar a preferência de pagamento' });
  }
}
