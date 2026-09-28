import test from 'node:test';import assert from 'node:assert/strict';import{readFileSync}from'node:fs';import{fileURLToPath}from'node:url';
const root=fileURLToPath(new URL('../',import.meta.url)),read=path=>readFileSync(`${root}${path}`,'utf8');
const cadastrosPage=read('src/app/(painel)/cadastros/page.tsx'),catalogoPage=read('src/app/(painel)/catalogo/page.tsx'),empresaPage=read('src/app/(painel)/empresa/page.tsx');
const switchBar=read('src/components/CadastroSwitchBar.tsx'),sidebar=read('src/components/SidebarNav.tsx');
const local=read('src/features/persistence/local.ts');

// M21-G5 — mesmo switcher validado no apps/portal (M21-G4), reaproveitado no
// apps/platform pra ter a mesma consistência visual entre os dois apps.
test('switcher tem os três destinos reais (Cadastros/Catálogo/Empresa)',()=>{
  assert.match(switchBar,/href="\/cadastros"/);
  assert.match(switchBar,/href="\/catalogo"/);
  assert.match(switchBar,/href="\/empresa"/);
});
test('as três páginas reais usam o switcher e o CSS validado',()=>{
  for(const page of[cadastrosPage,catalogoPage,empresaPage]){
    assert.match(page,/CadastroSwitchBar/);
    assert.match(page,/cc-classic\.css/);
  }
});
test('sidebar real inclui o link de Empresa',()=>assert.match(sidebar,/href:\s*'\/empresa'/));
test('rota \/empresa é aceita pelo redirect seguro do painel',()=>{
  const redirect=read('src/domain/redirect.mjs');
  assert.match(redirect,/'\/empresa'/);
});
test('Empresa lê estabelecimento real (listVisualEstablishments), sem edição de CNPJ/razão social',()=>{
  assert.match(empresaPage,/listVisualEstablishments/);
  assert.doesNotMatch(empresaPage,/name="cnpj"|name="legal_name"/);
});
test('aviso de empresa incompleta em Cadastros aponta pra \/empresa e não bloqueia (sem redirect)',()=>{
  assert.match(cadastrosPage,/empresaIncompleta/);
  assert.doesNotMatch(cadastrosPage,/empresaIncompleta[^]*redirect\(/);
});
test('LocalEstablishment ganhou legal_name/cnpj opcionais sem quebrar o seed sintético existente',()=>{
  assert.match(local,/legal_name\?:string\|null;cnpj\?:string\|null/);
  assert.match(local,/trade_name:'Loja Centro \(matriz\)'/);
});
