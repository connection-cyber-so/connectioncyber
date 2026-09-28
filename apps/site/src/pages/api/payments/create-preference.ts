import type { NextApiRequest, NextApiResponse } from 'next';
import { isMercadoPagoEnabled, isSupabaseConfigured } from '@/config/env';
import { createPaymentPreference, type PreferenceItemInput } from '@/lib/payments';
import { getSupabaseAdminClient } from '@/lib/supabaseClient';
import { consumeRateLimit } from '@/lib/rateLimit';
import { parseCheckoutItems, type CatalogType, type CheckoutItemInput } from '@/lib/checkoutValidation';

interface CatalogItem extends PreferenceItemInput {
  type: CatalogType;
}

async function loadCatalogItems(items: CheckoutItemInput[]): Promise<CatalogItem[]> {
  const admin = getSupabaseAdminClient();
  const courseIds = items.filter((item) => item.type === 'course').map((item) => item.id);
  const productIds = items.filter((item) => item.type === 'product').map((item) => item.id);

  const [coursesResult, productsResult] = await Promise.all([
    courseIds.length
      ? admin.from('courses').select('id, titulo, preco').in('id', courseIds).eq('status', 'publicado')
      : Promise.resolve({ data: [], error: null }),
    productIds.length
      ? admin.from('products').select('id, nome, preco, estoque').in('id', productIds).eq('status', 'ativo')
      : Promise.resolve({ data: [], error: null }),
  ]);

  if (coursesResult.error) throw coursesResult.error;
  if (productsResult.error) throw productsResult.error;

  const courses = new Map((coursesResult.data ?? []).map((item) => [item.id, item]));
  const products = new Map((productsResult.data ?? []).map((item) => [item.id, item]));

  return items.map((requested) => {
    if (requested.type === 'course') {
      const course = courses.get(requested.id);
      if (!course) throw new Error('Curso indisponível ou não publicado');
      const unitPrice = Number(course.preco);
      if (!Number.isFinite(unitPrice) || unitPrice <= 0) throw new Error('Curso sem preço válido para venda');
      return {
        id: requested.id,
        type: requested.type,
        title: String(course.titulo),
        quantity: requested.quantity,
        unitPrice,
        currencyId: 'BRL',
      };
    }

    const product = products.get(requested.id);
    if (!product) throw new Error('Produto indisponível ou inativo');
    const unitPrice = Number(product.preco);
    if (!Number.isFinite(unitPrice) || unitPrice <= 0) throw new Error('Produto sem preço válido para venda');
    if (product.estoque !== null && Number(product.estoque) < requested.quantity) {
      throw new Error('Quantidade indisponível em estoque');
    }
    return {
      id: requested.id,
      type: requested.type,
      title: String(product.nome),
      quantity: requested.quantity,
      unitPrice,
      currencyId: 'BRL',
    };
  });
}

/**
 * POST /api/payments/create-preference
 * O cliente informa apenas IDs, tipos e quantidades. Catálogo, título, preço,
 * moeda, tenant e total são sempre derivados no servidor.
 */
export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  if (req.method !== 'POST') {
    res.setHeader('Allow', 'POST');
    return res.status(405).json({ error: 'Método não permitido' });
  }

  if (!isMercadoPagoEnabled) {
    return res.status(503).json({ error: 'Pagamentos indisponíveis neste ambiente' });
  }
  if (!isSupabaseConfigured) {
    return res.status(503).json({ error: 'Catálogo indisponível' });
  }

  try {
    if (!(await consumeRateLimit(req, 'payment-preference', 10, 60))) {
      res.setHeader('Retry-After', '60');
      return res.status(429).json({ error: 'Muitas tentativas. Aguarde e tente novamente.' });
    }
  } catch (error) {
    console.error('[api/payments/create-preference] rate limit indisponível', error);
    return res.status(503).json({ error: 'Pagamento temporariamente indisponível' });
  }

  const requestedItems = parseCheckoutItems(req.body?.items);
  if (!requestedItems) {
    return res.status(400).json({ error: 'Itens inválidos' });
  }

  const admin = getSupabaseAdminClient();
  let orderId: string | null = null;

  try {
    const catalogItems = await loadCatalogItems(requestedItems);
    const totalInCents = catalogItems.reduce(
      (sum, item) => sum + Math.round(item.unitPrice * 100) * item.quantity,
      0,
    );
    const total = totalInCents / 100;

    const { data: tenant, error: tenantError } = await admin
      .from('tenants')
      .select('id')
      .eq('slug', 'connectioncyber')
      .single();
    if (tenantError || !tenant) throw new Error('Tenant ConnectionCyber não encontrado');

    const { data: order, error: orderError } = await admin
      .from('orders')
      .insert({ user_id: null, tenant_id: tenant.id, total, status: 'pendente' })
      .select('id')
      .single();
    if (orderError || !order) throw orderError ?? new Error('Pedido não criado');
    orderId = order.id;

    const { error: itemsError } = await admin.from('order_items').insert(
      catalogItems.map((item) => ({
        order_id: orderId,
        product_id: item.id,
        quantidade: item.quantity,
        preco_unitario: item.unitPrice,
      })),
    );
    if (itemsError) throw itemsError;

    const preference = await createPaymentPreference({ orderId: order.id, items: catalogItems });
    return res.status(200).json({ orderId, ...preference });
  } catch (error) {
    if (orderId) {
      await admin.from('orders').delete().eq('id', orderId);
    }
    console.error('[api/payments/create-preference] erro', error);
    return res.status(500).json({ error: 'Não foi possível iniciar o pagamento' });
  }
}
