import assert from 'node:assert/strict';
import test from 'node:test';
import {
  buildCdRpcCall,
  cdErrorMessage,
  cdNextActions,
  isCdCanal,
  isCdIntent,
  isUuidValue,
  parseCdItem,
} from '../src/domain/cd.ts';

const TENANT = '00000000-0000-0000-0000-000000000001';
const ID_A = '11111111-1111-1111-1111-111111111111';
const ID_B = '22222222-2222-2222-2222-222222222222';
const PROD = '33333333-3333-3333-3333-333333333333';

test('uuid: aceita formato canônico e recusa lixo', () => {
  assert.equal(isUuidValue(ID_A), true);
  assert.equal(isUuidValue('nao-e-uuid'), false);
  assert.equal(isUuidValue(''), false);
  assert.equal(isUuidValue(undefined), false);
});

test('intenção e canal: whitelist fail-closed', () => {
  assert.equal(isCdIntent('alocar_pedido'), true);
  assert.equal(isCdIntent('apagar_tudo'), false);
  assert.equal(isCdCanal('web'), true);
  assert.equal(isCdCanal('site'), false);
});

test('item: quantidade inteira positiva e preço não negativo, com vírgula decimal', () => {
  assert.deepEqual(parseCdItem({ produto_id: PROD, qtd: '60', preco_unit: '15,5' }), {
    produto_id: PROD,
    qtd: 60,
    preco_unit: 15.5,
  });
  assert.equal(parseCdItem({ produto_id: PROD, qtd: '0', preco_unit: '1' }), null);
  assert.equal(parseCdItem({ produto_id: PROD, qtd: '2.5', preco_unit: '1' }), null);
  assert.equal(parseCdItem({ produto_id: PROD, qtd: '1', preco_unit: '-1' }), null);
  assert.equal(parseCdItem({ produto_id: 'x', qtd: '1', preco_unit: '1' }), null);
});

test('ações por status: aguardando oferece alocar e aprovar; web coleta; balcão despacha', () => {
  assert.deepEqual(cdNextActions('aguardando_aprovacao', 'web'), ['alocar_pedido', 'aprovar_pedido']);
  assert.deepEqual(cdNextActions('autorizada', 'web'), ['coletar_pedido']);
  assert.deepEqual(cdNextActions('autorizada', 'balcao'), ['despachar_pedido']);
  assert.deepEqual(cdNextActions('coletado', 'web'), ['despachar_pedido']);
  assert.deepEqual(cdNextActions('despachado', 'web'), []);
});

test('RPC: cada intenção aponta para a função certa com os argumentos certos', () => {
  const criar = buildCdRpcCall('criar_pedido', {
    tenantId: TENANT,
    localId: ID_A,
    canal: 'web',
    item: { produto_id: PROD, qtd: 60, preco_unit: 15 },
  });
  assert.equal(criar?.fn, 'cd_api_criar_pedido');
  assert.deepEqual(criar?.args, {
    p_tenant_id: TENANT,
    p_local_id: ID_A,
    p_canal: 'web',
    p_itens: [{ produto_id: PROD, qtd: 60, preco_unit: 15 }],
  });

  const alocar = buildCdRpcCall('alocar_pedido', { tenantId: TENANT, pedidoId: ID_B });
  assert.equal(alocar?.fn, 'cd_api_alocar_pedido');
  assert.equal(alocar?.args.p_aprovado, false);

  const aprovar = buildCdRpcCall('aprovar_pedido', { tenantId: TENANT, pedidoId: ID_B });
  assert.equal(aprovar?.args.p_aprovado, true);

  assert.equal(buildCdRpcCall('receber_transferencia', { tenantId: TENANT, transferenciaId: ID_A })?.fn, 'cd_api_receber_transferencia');
  assert.equal(buildCdRpcCall('coletar_pedido', { tenantId: TENANT, pedidoId: ID_B })?.fn, 'cd_api_coletar_pedido');
  assert.equal(buildCdRpcCall('despachar_pedido', { tenantId: TENANT, pedidoId: ID_B })?.fn, 'cd_api_despachar_pedido');
});

test('RPC: campos ausentes ou tenant inválido não geram chamada', () => {
  assert.equal(buildCdRpcCall('alocar_pedido', { tenantId: 'x', pedidoId: ID_B }), null);
  assert.equal(buildCdRpcCall('alocar_pedido', { tenantId: TENANT, pedidoId: undefined }), null);
  assert.equal(buildCdRpcCall('criar_pedido', { tenantId: TENANT, localId: ID_A, canal: 'site', item: { produto_id: PROD, qtd: 1, preco_unit: 1 } }), null);
  assert.equal(buildCdRpcCall('criar_pedido', { tenantId: TENANT, localId: ID_A, canal: 'web' }), null);
});

test('erros: mensagens amigáveis para os códigos conhecidos, sem SQL bruto', () => {
  assert.match(cdErrorMessage('sem permissão stock.manage no tenant'), /permissão/);
  assert.match(cdErrorMessage('capacidade cd.expedicao inativa no tenant'), /plano/);
  assert.match(cdErrorMessage('há transferência não recebida para este pedido'), /transferência/);
  assert.match(cdErrorMessage('erro qualquer do banco: relation x'), /Não foi possível/);
  assert.doesNotMatch(cdErrorMessage('relation "public.x" does not exist'), /relation/);
});
