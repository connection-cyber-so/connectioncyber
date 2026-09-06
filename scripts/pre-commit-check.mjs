#!/usr/bin/env node
// scripts/pre-commit-check.mjs
//
// Git pre-commit hook: roda type-check (`tsc --noEmit`) e testes locais somente
// do(s) app(s)/pacote(s) afetados pelo commit atual, antes de permitir o commit.
//
// Regra de origem: GOVERNANCA-EXECUCAO-AUTOMATICA.md, seção "Protocolo Staging-First"
// — "Antes de todo commit: testes locais do(s) app(s)/pacote(s) afetado(s) + `npx tsc
// --noEmit` (ou `npm run type-check`) limpos. Corrigir antes de prosseguir, nunca
// commitar com tipo quebrado."
//
// Instalação (uma vez por clone): git config core.hooksPath .githooks
// Escape manual conhecido do git (uso excepcional, sob responsabilidade de quem commita):
// git commit --no-verify

import { execSync } from 'node:child_process';
import { existsSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');

function run(cmd, opts = {}) {
  return execSync(cmd, { cwd: repoRoot, encoding: 'utf8', ...opts });
}

function hasPackageJson(dir) {
  return existsSync(path.join(repoRoot, dir, 'package.json'));
}

function hasScript(dir, scriptName) {
  if (!hasPackageJson(dir)) return false;
  try {
    const pkg = JSON.parse(run(`node -e "console.log(JSON.stringify(require('./${dir}/package.json').scripts||{}))"`));
    return Boolean(pkg[scriptName]);
  } catch {
    return false;
  }
}

let stagedFiles;
try {
  stagedFiles = run('git diff --cached --name-only --diff-filter=ACMR')
    .split('\n')
    .map((line) => line.trim())
    .filter(Boolean);
} catch (err) {
  console.error('pre-commit: nao foi possivel obter arquivos staged, abortando.');
  console.error(err.message);
  process.exit(1);
}

if (stagedFiles.length === 0) {
  console.log('pre-commit: nenhum arquivo staged, nada a verificar.');
  process.exit(0);
}

const affected = new Set();
for (const file of stagedFiles) {
  const appMatch = file.match(/^apps\/([^/]+)\//);
  if (appMatch) affected.add(`apps/${appMatch[1]}`);
  const pkgMatch = file.match(/^packages\/([^/]+)\//);
  if (pkgMatch) affected.add(`packages/${pkgMatch[1]}`);
}

const targets = [...affected].filter(hasPackageJson).sort();

if (targets.length === 0) {
  console.log('pre-commit: nenhum app/pacote com package.json afetado, nada a verificar.');
  process.exit(0);
}

console.log(`pre-commit: verificando ${targets.join(', ')}`);

const failures = [];

for (const target of targets) {
  const dir = path.join(repoRoot, target);

  if (hasScript(target, 'type-check')) {
    console.log(`\n[${target}] npm run type-check`);
    try {
      execSync('npm run type-check', { cwd: dir, stdio: 'inherit' });
    } catch {
      failures.push(`${target}: type-check falhou`);
      continue;
    }
  }

  if (hasScript(target, 'test')) {
    console.log(`\n[${target}] npm test`);
    try {
      execSync('npm test', { cwd: dir, stdio: 'inherit' });
    } catch {
      failures.push(`${target}: testes falharam`);
    }
  }
}

if (failures.length > 0) {
  console.error('\npre-commit BLOQUEADO:');
  for (const f of failures) console.error(`  - ${f}`);
  console.error('\nCorrija antes de commitar (regra Protocolo Staging-First). Escape manual: git commit --no-verify');
  process.exit(1);
}

console.log('\npre-commit OK: type-check e testes limpos para os apps/pacotes afetados.');
process.exit(0);
