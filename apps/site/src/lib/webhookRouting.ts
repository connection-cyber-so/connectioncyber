/**
 * Classificação da notificação do Mercado Pago: separa o fluxo de
 * assinaturas (M25) do fluxo clássico de pedidos. Puro — testável
 * sem HTTP/Supabase/MP.
 */

export type WebhookClassification =
  | { kind: 'subscription'; topic: 'preapproval' | 'preapproval_payment'; id: string }
  | { kind: 'payment'; id: string }
  | { kind: 'invalid'; reason: 'missing-id' };

const SUBSCRIPTION_TOPICS = new Set(['preapproval', 'preapproval_payment']);

function firstString(value: string | string[] | undefined): string | undefined {
  return Array.isArray(value) ? value[0] : value;
}

export function classifyWebhookNotification(params: {
  query: Record<string, unknown>;
  body: unknown;
}): WebhookClassification {
  const { query, body } = params;

  const topic =
    firstString(query.topic as string | string[] | undefined) ??
    firstString(query.type as string | string[] | undefined) ??
    (typeof (body as { type?: unknown })?.type === 'string'
      ? ((body as { type: string }).type)
      : undefined);
  const id =
    firstString(query['data.id'] as string | string[] | undefined) ??
    (typeof (body as { data?: { id?: unknown } })?.data?.id === 'string'
      ? (body as { data: { id: string } }).data.id
      : undefined);

  if (!id) return { kind: 'invalid', reason: 'missing-id' };
  if (topic && SUBSCRIPTION_TOPICS.has(topic)) {
    return { kind: 'subscription', topic: topic as 'preapproval' | 'preapproval_payment', id };
  }
  return { kind: 'payment', id };
}
