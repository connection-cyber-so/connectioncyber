import assert from 'node:assert/strict';
import { createHmac } from 'node:crypto';
import test from 'node:test';
import { validateMercadoPagoWebhookSignature } from '../src/lib/webhookSignature.ts';

const dataId = '123456789';
const requestId = 'request-abc';
const secret = 'test-secret-not-a-real-credential';
const timestamp = '1735689600000';
const now = () => Number(timestamp);
const manifest = `id:${dataId};request-id:${requestId};ts:${timestamp};`;
const hash = createHmac('sha256', secret).update(manifest).digest('hex');

test('aceita assinatura HMAC válida dentro da tolerância', () => {
  assert.equal(
    validateMercadoPagoWebhookSignature({
      headers: { 'x-signature': `ts=${timestamp},v1=${hash}`, 'x-request-id': requestId },
      dataId,
      secret,
      now,
    }),
    true,
  );
});

test('rejeita assinatura adulterada, ausente ou expirada', () => {
  assert.equal(
    validateMercadoPagoWebhookSignature({
      headers: { 'x-signature': `ts=${timestamp},v1=${'0'.repeat(64)}`, 'x-request-id': requestId },
      dataId,
      secret,
      now,
    }),
    false,
  );
  assert.equal(validateMercadoPagoWebhookSignature({ headers: {}, dataId, secret, now }), false);
  assert.equal(
    validateMercadoPagoWebhookSignature({
      headers: { 'x-signature': `ts=${timestamp},v1=${hash}`, 'x-request-id': requestId },
      dataId,
      secret,
      now: () => Number(timestamp) + 301_000,
    }),
    false,
  );
});
