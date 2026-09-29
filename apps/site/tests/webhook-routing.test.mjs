import assert from 'node:assert/strict';
import test from 'node:test';
import { classifyWebhookNotification } from '../src/lib/webhookRouting.ts';

test('topic de assinatura na query vira fluxo de assinatura', () => {
  assert.deepEqual(
    classifyWebhookNotification({
      query: { topic: 'preapproval', 'data.id': 'mp-pre-1' },
      body: undefined,
    }),
    { kind: 'subscription', topic: 'preapproval', id: 'mp-pre-1' },
  );
  assert.deepEqual(
    classifyWebhookNotification({
      query: { type: 'preapproval_payment', 'data.id': 'pay-9' },
      body: undefined,
    }),
    { kind: 'subscription', topic: 'preapproval_payment', id: 'pay-9' },
  );
});

test('notificacao de pagamento segue o fluxo de pedidos', () => {
  assert.deepEqual(
    classifyWebhookNotification({
      query: { 'data.id': '12345', type: 'payment' },
      body: undefined,
    }),
    { kind: 'payment', id: '12345' },
  );
  assert.deepEqual(
    classifyWebhookNotification({ query: {}, body: { type: 'payment', data: { id: '777' } } }),
    { kind: 'payment', id: '777' },
  );
});

test('sem data.id a notificacao e invalida', () => {
  assert.deepEqual(
    classifyWebhookNotification({ query: { topic: 'preapproval' }, body: undefined }),
    { kind: 'invalid', reason: 'missing-id' },
  );
  assert.deepEqual(
    classifyWebhookNotification({ query: {}, body: { type: 'payment' } }),
    { kind: 'invalid', reason: 'missing-id' },
  );
});

test('id no corpo conta quando a query nao traz data.id', () => {
  assert.deepEqual(
    classifyWebhookNotification({
      query: { topic: 'preapproval' },
      body: { data: { id: 'mp-pre-body' } },
    }),
    { kind: 'subscription', topic: 'preapproval', id: 'mp-pre-body' },
  );
});
