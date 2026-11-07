import test from 'node:test';
import assert from 'node:assert/strict';
import {
  alcadaMessage,
  canRecordAuthorization,
  isValidPin,
  managerPinErrorMessage,
  parseAlcadaResult,
} from '../src/domain/pdv-alcada';

const UUID = '3f2504e0-4f89-41d3-9a0c-0305e82c3301';

test('PIN aceita somente 4 a 6 dígitos', () => {
  for (const ok of ['1234', '123456', '0000']) assert.equal(isValidPin(ok), true, ok);
  for (const bad of ['12', '1234567', '12a4', '', ' 1234', '1234\n']) assert.equal(isValidPin(bad), false, JSON.stringify(bad));
});

test('parse aceita autorizado com authorization_id uuid', () => {
  const r = parseAlcadaResult({ status: 'authorized', authorization_id: UUID });
  assert.deepEqual(r, { status: 'authorized', authorizationId: UUID });
  assert.equal(canRecordAuthorization(r), true);
});

test('parse aceita os três estados de bloqueio sem id', () => {
  for (const status of ['pin_invalid', 'pin_locked', 'pin_missing'] as const) {
    const r = parseAlcadaResult({ status });
    assert.deepEqual(r, { status });
    assert.equal(canRecordAuthorization(r), false);
  }
});

test('parse falha fechado em retorno fora do contrato', () => {
  assert.throws(() => parseAlcadaResult(null), /ALCADA_RESULT_INVALIDO/);
  assert.throws(() => parseAlcadaResult('authorized'), /ALCADA_RESULT_INVALIDO/);
  assert.throws(() => parseAlcadaResult({ status: 'authorized' }), /ALCADA_RESULT_SEM_ID/);
  assert.throws(() => parseAlcadaResult({ status: 'authorized', authorization_id: 'x' }), /ALCADA_RESULT_SEM_ID/);
  assert.throws(() => parseAlcadaResult({ status: 'ok' }), /ALCADA_RESULT_STATUS_DESCONHECIDO/);
});

test('mensagens cobrem bloqueio de 15 minutos e cadastro pelo gerente', () => {
  assert.match(alcadaMessage({ status: 'pin_locked' }), /15 minutos/);
  assert.match(alcadaMessage({ status: 'pin_missing' }), /gerente/);
  assert.match(alcadaMessage({ status: 'pin_invalid' }), /incorreto/);
});

test('erros do cadastro de PIN mapeiam SQLSTATE sem vazar detalhe interno', () => {
  assert.match(managerPinErrorMessage('22023'), /4 a 6/);
  assert.match(managerPinErrorMessage('42501'), /Sem permissão/);
  assert.match(managerPinErrorMessage('23514'), /alçada/);
  assert.equal(managerPinErrorMessage('XX000'), 'Não foi possível cadastrar o PIN.');
});
