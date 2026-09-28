import assert from 'node:assert/strict';
import test from 'node:test';
import { parseCheckoutItems } from '../src/lib/checkoutValidation.ts';

const VALID_ID = '123e4567-e89b-42d3-a456-426614174000';

test('aceita somente identificador, tipo e quantidade válidos', () => {
  assert.deepEqual(parseCheckoutItems([{ id: VALID_ID, type: 'course', quantity: 1 }]), [
    { id: VALID_ID, type: 'course', quantity: 1 },
  ]);
});

test('rejeita preço ou título enviados pelo navegador', () => {
  assert.equal(
    parseCheckoutItems([{ id: VALID_ID, type: 'course', quantity: 1, unitPrice: 0.01, title: 'adulterado' }]),
    null,
  );
});

test('rejeita UUID inválido, quantidade fora do limite e itens duplicados', () => {
  assert.equal(parseCheckoutItems([{ id: 'curso-demo', type: 'course', quantity: 1 }]), null);
  assert.equal(parseCheckoutItems([{ id: VALID_ID, type: 'product', quantity: 11 }]), null);
  assert.equal(
    parseCheckoutItems([
      { id: VALID_ID, type: 'product', quantity: 1 },
      { id: VALID_ID, type: 'product', quantity: 1 },
    ]),
    null,
  );
});
