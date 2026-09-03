import assert from 'node:assert/strict';
import test from 'node:test';
import { readFileSync } from 'node:fs';

const layout = readFileSync(new URL('../src/app/(portal)/layout.tsx', import.meta.url), 'utf8');
const brand = readFileSync(new URL('../src/components/Brand.tsx', import.meta.url), 'utf8');
const page = readFileSync(new URL('../src/app/(portal)/configuracoes/aparencia/page.tsx', import.meta.url), 'utf8');
const route = readFileSync(new URL('../src/app/auth/set-branding/route.ts', import.meta.url), 'utf8');
const libBranding = readFileSync(new URL('../src/lib/branding.ts', import.meta.url), 'utf8');

test('layout carrega branding do tenant e só mostra a engrenagem com permissão', () => {
  assert.match(layout, /loadTenantBranding/);
  assert.match(layout, /canManageBranding/);
  assert.match(layout, /canEditBranding \? \(/);
});

test('layout sobrepõe --orange só quando a cor salva é válida (defesa em profundidade)', () => {
  assert.match(layout, /isValidHexColor\(branding\.primaryColor\)/);
  assert.match(layout, /--orange:\$\{branding\.primaryColor\}/);
});

test('Brand aceita logoUrl opcional com fallback pro logo oficial', () => {
  assert.match(brand, /logoUrl\?:\s*string \| null/);
  assert.match(brand, /connectionCyberLogo/);
});

test('tela de aparência nunca redireciona quem não tem permissão — só avisa', () => {
  assert.match(page, /canEdit \?/);
  assert.doesNotMatch(page, /if \(!canEdit\)[^]*redirect\(/);
});

test('route de set-branding faz same-origin check e revalida no servidor', () => {
  assert.match(route, /isSameOriginRequest/);
  assert.match(route, /status: 403/);
  assert.match(route, /isValidHexColor|normalizeHexColor/);
  assert.match(route, /isValidLogoUrl|normalizeLogoUrl/);
});

test('tenant sempre vem da sessão (loadPortalAccess), nunca de input do formulário', () => {
  assert.match(route, /access\.membership\.tenantId/);
  assert.doesNotMatch(route, /formData\.get\('tenant_id'\)/);
});

test('escrita real é sempre pela RPC erp_set_tenant_branding — nenhum insert direto na tabela', () => {
  assert.match(route, /\.rpc\('erp_set_tenant_branding'/);
  assert.doesNotMatch(route, /\.from\('erp_tenant_branding'\)\.insert/);
  assert.doesNotMatch(route, /\.from\('erp_tenant_branding'\)\.update/);
});

test('nada nesta feature usa service_role — permissão sempre pela sessão do próprio usuário', () => {
  for (const source of [layout, page, route, libBranding, brand]) {
    assert.doesNotMatch(source, /service_role/i);
  }
});

test('lib/branding.ts falha aberto pra leitura (cosmético) e fechado pra escrita (permissão)', () => {
  assert.match(libBranding, /catch \{\s*return DEFAULT_BRANDING/);
  assert.match(libBranding, /catch \{\s*return false/);
});
