import test from 'node:test';import assert from 'node:assert/strict';import{readFileSync}from'node:fs';import{fileURLToPath}from'node:url';
const root=fileURLToPath(new URL('../',import.meta.url)),read=path=>readFileSync(`${root}${path}`,'utf8');
const local=read('src/features/persistence/local.ts'),selected=read('src/features/persistence/selected.ts');
const partyDetail=read('src/features/parties/components/PartyDetailPanel.tsx'),partyList=read('src/features/parties/components/PartyList.tsx');
const itemDetail=read('src/features/catalog/components/ItemDetailPanel.tsx'),catalogList=read('src/features/catalog/components/CatalogList.tsx');
const scope=read('src/lib/establishment-scope.ts'),switcher=read('src/components/EstablishmentSwitcher.tsx');
const cadastrosPage=read('src/app/(painel)/cadastros/page.tsx'),catalogoPage=read('src/app/(painel)/catalogo/page.tsx'),operacoesPage=read('src/app/(painel)/operacoes/page.tsx'),vendasPage=read('src/app/(painel)/vendas/page.tsx'),servicosPage=read('src/app/(painel)/servicos/page.tsx');
const salesService=read('src/features/sales/service.ts'),servicesService=read('src/features/services/service.ts'),establishmentsService=read('src/features/establishments/service.ts');

// M20-G3 — abas de cadastro/catálogo
test('transporte sintético ganha os seis comandos novos do M20-G3/G4',()=>{for(const rpc of['erp_command_add_party_document_v1','erp_command_add_party_contact_v1','erp_command_add_party_address_v1','erp_command_set_item_fiscal_data_v1','erp_command_set_item_commercial_data_v1','erp_command_set_establishment_vertical_v1'])assert.match(local,new RegExp(rpc.replace(/\./g,'\\.')));});
test('fachada selecionada expõe as novas leituras M20-G3/G4',()=>{for(const fn of['listVisualPartyDocuments','listVisualPartyContacts','listVisualPartyAddresses','listVisualItemFiscalData','listVisualItemCommercialData','listVisualBusinessVerticals','listVisualVerticalAttributeRequirements','listVisualEstablishments'])assert.match(selected,new RegExp(fn));});
test('painel de pessoa cobre documentos contatos e endereços',()=>{for(const label of['Documentos','Contatos','Endereços'])assert.match(partyDetail,new RegExp(label));});
test('lista de pessoas anexa o painel de detalhe por cadastro',()=>assert.match(partyList,/PartyDetailPanel/));
test('painel de item cobre fiscal comercial e atributos do segmento',()=>{for(const label of['Fiscal','Comercial','Atributos do segmento'])assert.match(itemDetail,new RegExp(label));});
test('lista de itens anexa o painel de detalhe por item',()=>assert.match(catalogList,/ItemDetailPanel/));
test('painéis de detalhe usam <details> nativo, sem JS de navegação por aba',()=>{for(const source of[partyDetail,itemDetail])assert.match(source,/<details/);});

// M20-G4 — seletor de estabelecimento
test('escopo de estabelecimento é somente cookie de exibição, nunca Supabase',()=>assert.doesNotMatch(scope,/createClient|@supabase/));
test('seletor de estabelecimento é formulário sem JS de cliente',()=>{assert.doesNotMatch(switcher,/'use client'/);assert.match(switcher,/<form action=\{setEstablishmentScopeAction\}/);});
test('operações catálogo vendas e serviços usam o seletor de estabelecimento',()=>{for(const page of[operacoesPage,catalogoPage,vendasPage,servicosPage])assert.match(page,/EstablishmentSwitcher/);});
test('cadastros usa as novas leituras de documento contato e endereço',()=>{for(const fn of['listVisualPartyDocuments','listVisualPartyContacts','listVisualPartyAddresses'])assert.match(cadastrosPage,new RegExp(fn));});
test('vendas e serviços filtram por establishmentId sem quebrar leitura sem filtro',()=>{assert.match(salesService,/establishmentId\?:string\|null/);assert.match(servicesService,/establishmentId\?:string\|null/);});
test('listagem real de estabelecimentos filtra por tenant e ativo',()=>{assert.match(establishmentsService,/eq\('tenant_id',\s*tenantId\)/);assert.match(establishmentsService,/eq\('active',\s*true\)/);});
test('página de estoque documenta que o saldo sintético ainda é consolidado por tenant',()=>assert.match(operacoesPage,/consolidado/));
