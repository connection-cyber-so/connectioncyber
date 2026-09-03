import assert from 'node:assert/strict';
import test from 'node:test';
import { readFileSync } from 'node:fs';

const login = readFileSync(new URL('../src/pages/login/index.tsx', import.meta.url), 'utf8');

test('os 3 caminhos estão presentes', () => {
  assert.match(login, /Sou aluno ou faço parte da Academy/);
  assert.match(login, /Sou da equipe ConnectionCyber/);
  assert.match(login, /Sou empresa com portal próprio/);
});

test('usa safeSiteRedirect em vez do redirect cru da query string', () => {
  assert.match(login, /safeSiteRedirect\(router\.query\.redirect\)/);
  assert.doesNotMatch(login, /router\.query\.redirect \? router\.query\.redirect/);
});

test('card da equipe mostra o endereço como texto, nunca como link clicável', () => {
  const teamCard = login.slice(login.indexOf('Sou da equipe ConnectionCyber'));
  const beforeNextCard = teamCard.slice(0, teamCard.indexOf('Sou empresa com portal próprio'));
  assert.match(beforeNextCard, /<code>platform\.connectioncyber\.com\.br<\/code>/);
  assert.doesNotMatch(beforeNextCard, /<a\s/);
  assert.doesNotMatch(beforeNextCard, /href=/);
});

test('caminho da empresa nunca chama a rede — só monta URL e navega no cliente', () => {
  const companySection = login.slice(login.indexOf('handleCompanySubmit'));
  assert.doesNotMatch(companySection, /fetch\(/);
  assert.match(login, /window\.location\.href = url/);
});

test('nenhum endpoint novo de lookup por e-mail nem uso de service_role nesta página', () => {
  assert.doesNotMatch(login, /service_role/i);
  assert.doesNotMatch(login, /resolveTenantForEmail|resolveLoginDestination|lookupTenant/i);
});
