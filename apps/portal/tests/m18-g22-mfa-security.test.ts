import assert from 'node:assert/strict';
import test from 'node:test';
import { readFileSync, readdirSync, statSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { decideMfaGate, MFA_SECURITY_PATH } from '../src/domain/mfa-gate.ts';

test('sem exigência de aal2, sempre libera', () => {
  assert.equal(
    decideMfaGate({ requiresAal2: false, currentLevel: 'aal1', pathname: '/dashboard' }),
    'allow'
  );
});

test('exige aal2, sessão em aal1, fora da tela de segurança: redireciona', () => {
  assert.equal(
    decideMfaGate({ requiresAal2: true, currentLevel: 'aal1', pathname: '/dashboard' }),
    'redirect-to-security'
  );
});

test('exige aal2, sessão em aal1, já na tela de segurança: libera (sem loop)', () => {
  assert.equal(
    decideMfaGate({ requiresAal2: true, currentLevel: 'aal1', pathname: MFA_SECURITY_PATH }),
    'allow'
  );
});

test('exige aal2, sessão já em aal2: libera em qualquer rota', () => {
  assert.equal(
    decideMfaGate({ requiresAal2: true, currentLevel: 'aal2', pathname: '/dashboard' }),
    'allow'
  );
});

// M18-G22 — o resto do app é 100% formulário + Route Handler de propósito
// (menor superfície de chamada direta à API do Supabase no navegador).
// Qualquer novo arquivo que passe a importar o client do browser precisa
// justificar por quê e ser adicionado aqui deliberadamente — nunca por
// acidente de um import solto.
const ALLOWED_BROWSER_CLIENT_CONSUMERS = new Set([
  'app/auth/confirm/page.tsx',
  'components/SecurityMfaPanel.tsx',
]);

function listSourceFiles(dir: string, root: string, out: string[] = []): string[] {
  for (const entry of readdirSync(dir)) {
    const full = join(dir, entry);
    const stat = statSync(full);
    if (stat.isDirectory()) {
      listSourceFiles(full, root, out);
    } else if (/\.(ts|tsx)$/.test(entry)) {
      out.push(full.slice(root.length + 1).replace(/\\/g, '/'));
    }
  }
  return out;
}

test('client Supabase do browser só é importado pelos consumidores deliberados', () => {
  const srcRoot = fileURLToPath(new URL('../src', import.meta.url));
  const files = listSourceFiles(srcRoot, srcRoot);
  const actualConsumers = files.filter((relativePath) => {
    const content = readFileSync(join(srcRoot, relativePath), 'utf8');
    return /@\/lib\/supabase\/client['"]/.test(content);
  });
  assert.deepEqual(new Set(actualConsumers), ALLOWED_BROWSER_CLIENT_CONSUMERS);
});

test('gate de MFA no layout usa erro fail-closed: erro assume aal2 exigido/não satisfeito', () => {
  const mfaLib = readFileSync(new URL('../src/lib/mfa.ts', import.meta.url), 'utf8');
  assert.match(mfaLib, /catch\s*\{\s*return true;\s*\}/);
  assert.match(mfaLib, /catch\s*\{\s*return 'aal1';\s*\}/);
});
