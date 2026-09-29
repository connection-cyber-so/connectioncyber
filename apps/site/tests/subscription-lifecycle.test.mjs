import assert from 'node:assert/strict';
import test from 'node:test';
import {
  decideSubscriptionAction,
  processSubscriptionNotification,
} from '../src/lib/subscriptionLifecycle.ts';

test('authorized com intencao aberta provisiona a empresa', () => {
  const action = decideSubscriptionAction({
    mpStatus: 'authorized',
    hasOpenIntent: true,
    hasSubscription: false,
    periodEnd: '2027-01-15T00:00:00.000Z',
  });
  assert.deepEqual(action, { kind: 'activate', periodEnd: '2027-01-15T00:00:00.000Z' });
});

test('authorized com assinatura existente reativa capabilities', () => {
  const action = decideSubscriptionAction({
    mpStatus: 'authorized',
    hasOpenIntent: false,
    hasSubscription: true,
  });
  assert.deepEqual(action, { kind: 'set_status', status: 'active' });
});

test('cancelled e paused so age quando ha assinatura', () => {
  assert.deepEqual(
    decideSubscriptionAction({ mpStatus: 'cancelled', hasOpenIntent: false, hasSubscription: true }),
    { kind: 'set_status', status: 'cancelled' },
  );
  assert.deepEqual(
    decideSubscriptionAction({ mpStatus: 'paused', hasOpenIntent: false, hasSubscription: true }),
    { kind: 'set_status', status: 'paused' },
  );
  assert.deepEqual(
    decideSubscriptionAction({ mpStatus: 'cancelled', hasOpenIntent: false, hasSubscription: false }),
    { kind: 'none' },
  );
});

test('status pendente ou desconhecido nao faz nada', () => {
  assert.deepEqual(
    decideSubscriptionAction({ mpStatus: 'pending', hasOpenIntent: true, hasSubscription: false }),
    { kind: 'none' },
  );
  assert.deepEqual(
    decideSubscriptionAction({ mpStatus: null, hasOpenIntent: true, hasSubscription: false }),
    { kind: 'none' },
  );
});

test('notificacao authorized provisiona, grava e marca o evento', async () => {
  const calls = [];
  const admin = {
    rpc: async (name, args) => {
      calls.push(name);
      return { data: {}, error: null };
    },
    from: (table) => ({
      select: () => ({
        eq: () => ({
          maybeSingle: async () => ({
            data:
              table === 'saas_checkout_intents'
                ? { id: 'intent-1', status: 'sent' }
                : null,
            error: null,
          }),
        }),
      }),
    }),
  };

  const outcome = await processSubscriptionNotification(admin, {
    topic: 'preapproval',
    externalId: 'mp-pre-1',
    snapshot: {
      id: 'mp-pre-1',
      status: 'authorized',
      externalReference: 'intent-1',
      nextPaymentDate: '2027-02-01T00:00:00.000Z',
    },
    payload: { type: 'preapproval' },
  });

  assert.deepEqual(outcome, { action: 'provisioned', matched: true });
  assert.deepEqual(calls, [
    'saas_record_billing_event_v1',
    'saas_activate_intent_v1',
    'saas_mark_billing_event_processed_v1',
  ]);
});

test('preapproval_payment sem snapshot so audita o evento', async () => {
  const calls = [];
  const admin = {
    rpc: async (name) => {
      calls.push(name);
      return { data: {}, error: null };
    },
    from: () => {
      throw new Error('nao deve consultar estado sem snapshot');
    },
  };

  const outcome = await processSubscriptionNotification(admin, {
    topic: 'preapproval_payment',
    externalId: 'pay-1',
    snapshot: null,
    payload: { type: 'preapproval_payment' },
  });

  assert.deepEqual(outcome, { action: 'recorded', matched: false });
  assert.deepEqual(calls, [
    'saas_record_billing_event_v1',
    'saas_mark_billing_event_processed_v1',
  ]);
});

test('falha da RPC propaga erro para o webhook responder 500', async () => {
  const admin = {
    rpc: async () => ({ data: null, error: { message: 'boom' } }),
    from: () => {
      throw new Error('nao deve chegar aqui');
    },
  };

  await assert.rejects(
    () =>
      processSubscriptionNotification(admin, {
        topic: 'preapproval',
        externalId: 'mp-pre-2',
        snapshot: null,
        payload: {},
      }),
    /registro do evento de billing/,
  );
});
