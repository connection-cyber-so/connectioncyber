import type { NextApiRequest, NextApiResponse } from 'next';
import { isMercadoPagoEnabled, isSupabaseConfigured } from '@/config/env';
import { createSubscriptionPreapproval } from '@/lib/payments';
import { getSupabaseAdminClient } from '@/lib/supabaseClient';
import { consumeRateLimit } from '@/lib/rateLimit';
import { parseTenantSignup } from '@/lib/subscriptionValidation';

const PLAN_CODE_PATTERN = /^[a-z0-9][a-z0-9-]{1,30}$/;
const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

function bearerToken(headers: NextApiRequest['headers']): string | null {
  const header = headers.authorization;
  if (!header || !header.startsWith('Bearer ')) return null;
  return header.slice('Bearer '.length);
}

/**
 * POST /api/payments/create-subscription — cria a intenção de assinatura
 * (M25) e o Preapproval recorrente no Mercado Pago.
 * Exige usuário autenticado: a empresa provisionada no primeiro pagamento
 * tem o usuário logado como dono.
 */
export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  if (req.method !== 'POST') {
    res.setHeader('Allow', 'POST');
    return res.status(405).json({ error: 'Método não permitido' });
  }
  if (!isMercadoPagoEnabled) {
    return res.status(503).json({ error: 'Assinaturas indisponíveis neste ambiente' });
  }
  if (!isSupabaseConfigured) {
    return res.status(503).json({ error: 'Serviços não configurados' });
  }

  try {
    if (!(await consumeRateLimit(req, 'subscription', 6, 60))) {
      res.setHeader('Retry-After', '60');
      return res.status(429).json({ error: 'Muitas tentativas. Aguarde e tente novamente.' });
    }
  } catch (error) {
    console.error('[api/payments/create-subscription] rate limit indisponível', error);
    return res.status(503).json({ error: 'Assinatura temporariamente indisponível' });
  }

  const token = bearerToken(req.headers);
  if (!token) {
    return res.status(401).json({ error: 'Faça login para assinar' });
  }

  const planCode = typeof req.body?.planCode === 'string' ? req.body.planCode : '';
  if (!PLAN_CODE_PATTERN.test(planCode)) {
    return res.status(400).json({ error: 'Plano inválido' });
  }
  const tenant = parseTenantSignup(req.body?.tenant);
  if (!tenant) {
    return res.status(400).json({ error: 'Dados da empresa inválidos' });
  }

  const admin = getSupabaseAdminClient();

  try {
    const { data: authData, error: authError } = await admin.auth.getUser(token);
    if (authError || !authData?.user) {
      return res.status(401).json({ error: 'Sessão inválida. Faça login novamente.' });
    }
    const userId = authData.user.id;

    const { data: activeSubs, error: subError } = await admin
      .from('saas_subscriptions')
      .select('id')
      .eq('owner_user_id', userId)
      .in('status', ['active', 'past_due'])
      .limit(1);
    if (subError) throw subError;
    if (activeSubs?.length) {
      return res.status(409).json({ error: 'Você já possui uma assinatura ativa.' });
    }

    const { data: plan, error: planError } = await admin
      .from('saas_plans')
      .select('id, code, name, price_cents')
      .eq('code', planCode)
      .eq('active', true)
      .maybeSingle();
    if (planError) throw planError;
    if (!plan) {
      return res.status(404).json({ error: 'Plano indisponível' });
    }

    const { data: intent, error: intentError } = await admin.rpc('saas_create_checkout_intent_v1', {
      p_user_id: userId,
      p_plan_code: planCode,
      p_tenant_payload: tenant,
    });
    if (intentError) {
      const message = intentError.message ?? '';
      if (message.includes('tenant already exists')) {
        return res.status(409).json({
          error: 'Já existe uma empresa com este CNPJ, slug ou domínio.',
        });
      }
      if (message.includes('owner identity not ready')) {
        return res.status(409).json({ error: 'Complete seu cadastro antes de assinar.' });
      }
      if (message.includes('invalid tenant payload')) {
        return res.status(400).json({ error: 'Dados da empresa inválidos' });
      }
      throw intentError;
    }

    const intentId = String((intent as { intentId?: string } | null)?.intentId ?? '');
    if (!UUID_PATTERN.test(intentId)) {
      throw new Error('Intenção de assinatura sem identificador');
    }

    const preapproval = await createSubscriptionPreapproval({
      intentId,
      reason: String(plan.name ?? 'Assinatura ConnectionCyber'),
      amountCents: Number(plan.price_cents),
      payerEmail: authData.user.email ?? undefined,
    });

    const { error: bindError } = await admin.rpc('saas_bind_preapproval_v1', {
      p_intent_id: intentId,
      p_preapproval_id: preapproval.preapprovalId,
      p_customer_id: preapproval.payerId ?? '',
    });
    if (bindError) throw bindError;

    return res.status(200).json({
      intentId,
      preapprovalId: preapproval.preapprovalId,
      checkoutUrl: preapproval.checkoutUrl,
    });
  } catch (error) {
    console.error('[api/payments/create-subscription] erro', error);
    return res.status(500).json({ error: 'Não foi possível iniciar a assinatura' });
  }
}
