import test from'node:test';import assert from'node:assert/strict';import{readFileSync}from'node:fs';
const root=new URL('../src/',import.meta.url),read=path=>readFileSync(new URL(path,root),'utf8'),persistent=read('features/persistence/persistent.ts'),local=read('features/persistence/local.ts');
const screens=['app/(painel)/page.tsx','app/(painel)/cadastros/page.tsx','app/(painel)/catalogo/page.tsx','app/(painel)/operacoes/page.tsx','app/(painel)/pdv/page.tsx','app/(painel)/financeiro/page.tsx'].map(read).join('\n');
test('composição persistente é exclusivamente server-side',()=>assert.match(persistent,/import 'server-only'/));
test('composição injeta adaptador e agregador no broker',()=>{assert.match(persistent,/createSupabasePersistenceTransport/);assert.match(persistent,/createSupabaseAggregateReader/);assert.match(persistent,/createVisualPersistenceClient/);});
test('tenant continua vindo de resolvedor server-side injetado',()=>assert.match(persistent,/resolveTenant: options\.resolveTenant/));
test('composição não cria cliente nem lê ambiente por conta própria',()=>assert.doesNotMatch(persistent,/createClient\(|process\.env|NEXT_PUBLIC/));
test('telas usam fachada selecionada sem importar composição persistente',()=>{assert.match(screens,/features\/persistence\/selected/);assert.doesNotMatch(screens,/features\/persistence\/persistent/);assert.match(local,/M18-G5/);});
test('marcador declara ativação remota bloqueada',()=>assert.match(persistent,/ativação remota bloqueada/));
