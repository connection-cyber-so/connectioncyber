import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const localeFiles = ['pt-BR', 'en-US', 'es-419'];
const dictionaries = Object.fromEntries(
  await Promise.all(
    localeFiles.map(async (locale) => {
      const url = new URL(`../src/i18n/${locale}.json`, import.meta.url);
      return [locale, JSON.parse(await readFile(url, 'utf8'))];
    }),
  ),
);

function describeShape(value, path = '') {
  if (typeof value === 'string') {
    assert.notEqual(value.trim(), '', `Tradução vazia em ${path}`);
    return 'string';
  }
  if (Array.isArray(value)) {
    return value.map((item, index) => describeShape(item, `${path}[${index}]`));
  }
  assert.ok(value && typeof value === 'object', `Valor inválido em ${path}`);
  return Object.fromEntries(
    Object.keys(value)
      .sort()
      .map((key) => [key, describeShape(value[key], path ? `${path}.${key}` : key)]),
  );
}

const baseline = describeShape(dictionaries['pt-BR']);
for (const locale of localeFiles.slice(1)) {
  assert.deepEqual(
    describeShape(dictionaries[locale]),
    baseline,
    `${locale} não possui a mesma estrutura de pt-BR`,
  );
}

console.log(`i18n: ${localeFiles.join(', ')} possuem estrutura equivalente e valores preenchidos.`);
