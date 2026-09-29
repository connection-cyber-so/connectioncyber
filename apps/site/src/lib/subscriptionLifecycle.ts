/**
 * Ciclo de vida da assinatura M25 — decide e aplica as transições que o
 * webhook do Mercado Pago pode disparar sobre uma intenção/assinatura.
 * A lógica de decisão é pura (testável sem Supabase/MP); a orquestração
 * recebe o cliente admin injetado.
 * Módulo server-side (API routes) — nunca importar no browser.
 */

export interface PreapprovalSnapshot {
  id: string;
  status: string | null;
  externalReference: string | null;
  nextPaymentDate: string | null;
}

export type SubscriptionAction =
  | { kind: 'activate'; periodEnd: string }
  | { kind: 'set_status'; status: 'active' | 'cancelled' | 'paused' | 'past_due' }
  | { kind: 'none' };

/** Mapeia o status do Preapproval (MP) + estado local para uma ação. */
export function decideSubscriptionAction(params: {
  mpStatus: string | null;
  hasOpenIntent: boolean;
  hasSubscription: boolean;
  periodEnd?: string;
}): SubscriptionAction {
  const { mpStatus, hasOpenIntent, hasSubscription } = params;

  switch (mpStatus) {
    case 'authorized':
      if (hasOpenIntent) {
        return {
          kind: 'activate',
          periodEnd: params.periodEnd ?? defaultPeriodEnd(),
        };
      }
      if (hasSubscription) return { kind: 'set_status', status: 'active' };
      return { kind: 'none' };
    case 'cancelled':
      return hasSubscription ? { kind: 'set_status', status: 'cancelled' } : { kind: 'none' };
    case 'paused':
      return hasSubscription ? { kind: 'set_status', status: 'paused' } : { kind: 'none' };
    default:
      return { kind: 'none' };
  }
}

function defaultPeriodEnd(): string {
  const date = new Date();
  date.setMonth(date.getMonth() + 1);
  return date.toISOString();
}

export interface SubscriptionAdminClient {
  rpc(
    name: string,
    args?: Record<string, unknown>,
  ): PromiseLike<{ data: unknown; error: { message?: string; code?: string } | null }>;
  from(table: string): {
    select(columns: string): {
      eq(column: string, value: unknown): {
        maybeSingle(): PromiseLike<{ data: Record<string, unknown> | null; error: unknown }>;
        limit(count: number): PromiseLike<{ data: Record<string, unknown>[] | null; error: unknown }>;
        in(
          column: string,
          values: unknown[],
        ): PromiseLike<{ data: Record<string, unknown>[] | null; error: unknown }>;
      };
    };
  };
}

function must<T>(result: { data: T; error: unknown }, context: string): T {
  if (result.error) {
    const detail =
      result.error instanceof Error
        ? result.error.message
        : JSON.stringify(result.error);
    throw new Error(`${context}: ${detail}`);
  }
  return result.data;
}

export interface SubscriptionNotification {
  topic: 'preapproval' | 'preapproval_payment';
  externalId: string;
  snapshot: PreapprovalSnapshot | null;
  payload: unknown;
}

/**
 * Processa uma notificação de assinatura:
 * 1) grava o evento (auditoria idempotente);
 * 2) decide/aplica a transição (activate / set_status);
 * 3) marca o evento como processado.
 * Lança em caso de falha — o webhook responde 500 e o MP reenvia.
 */
export async function processSubscriptionNotification(
  admin: SubscriptionAdminClient,
  notification: SubscriptionNotification,
): Promise<{ action: string; matched: boolean }> {
  const { topic, externalId, snapshot, payload } = notification;

  must(
    await admin.rpc('saas_record_billing_event_v1', {
      p_topic: topic,
      p_external_id: externalId,
      p_preapproval_id: snapshot?.id ?? null,
      p_payment_id: null,
      p_status: snapshot?.status ?? null,
      p_payload: payload ?? {},
    }),
    'registro do evento de billing',
  );

  if (!snapshot) {
    must(
      await admin.rpc('saas_mark_billing_event_processed_v1', {
        p_topic: topic,
        p_external_id: externalId,
        p_result: 'recorded',
      }),
      'marcacao do evento',
    );
    return { action: 'recorded', matched: false };
  }

  const intent = must(
    await admin
      .from('saas_checkout_intents')
      .select('id, status')
      .eq('mp_preapproval_id', snapshot.id)
      .maybeSingle(),
    'leitura da intencao',
  );
  const subscription = must(
    await admin
      .from('saas_subscriptions')
      .select('id, status')
      .eq('mp_preapproval_id', snapshot.id)
      .maybeSingle(),
    'leitura da assinatura',
  );

  const openIntentStatuses = ['created', 'sent', 'failed'];
  const action = decideSubscriptionAction({
    mpStatus: snapshot.status,
    hasOpenIntent: Boolean(intent) && openIntentStatuses.includes(String(intent?.status)),
    hasSubscription: Boolean(subscription),
    periodEnd: snapshot.nextPaymentDate ?? undefined,
  });

  let result = 'noop';
  if (action.kind === 'activate') {
    must(
      await admin.rpc('saas_activate_intent_v1', {
        p_preapproval_id: snapshot.id,
        p_period_end: action.periodEnd,
      }),
      'ativacao da assinatura',
    );
    result = 'provisioned';
  } else if (action.kind === 'set_status') {
    must(
      await admin.rpc('saas_set_subscription_status_v1', {
        p_preapproval_id: snapshot.id,
        p_status: action.status,
        p_reason: `webhook preapproval: ${snapshot.status ?? 'desconhecido'}`,
      }),
      'atualizacao da assinatura',
    );
    result = `status:${action.status}`;
  }

  must(
    await admin.rpc('saas_mark_billing_event_processed_v1', {
      p_topic: topic,
      p_external_id: externalId,
      p_result: result,
    }),
    'marcacao do evento',
  );

  return { action: result, matched: Boolean(intent || subscription) };
}
