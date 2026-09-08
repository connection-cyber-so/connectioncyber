import test from 'node:test';
import assert from 'node:assert/strict';
import {
  isValidCPF,
  isValidCNPJ,
  isValidTaxId,
  formatCPF,
  formatCNPJ,
  formatTaxId,
  formatPhone,
  onlyDigits,
} from '../src/domain/br-documents.mjs';

// M20-G6 — CPF/CNPJ com dígito verificador real (mod-11), não só contagem de dígitos.
// "111.444.777-35" e "11.222.333/0001-81" são exemplos-padrão de dígito válido usados
// publicamente para teste (mesmo par usado no algoritmo da Receita), não dados reais.

test('CPF válido com dígito verificador correto', () => {
  assert.equal(isValidCPF('111.444.777-35'), true);
  assert.equal(isValidCPF('11144477735'), true);
});

test('CPF rejeitado: dígito verificador errado', () => {
  assert.equal(isValidCPF('111.444.777-36'), false);
});

test('CPF rejeitado: todos os dígitos iguais', () => {
  assert.equal(isValidCPF('111.111.111-11'), false);
});

test('CPF rejeitado: tamanho errado', () => {
  assert.equal(isValidCPF('123'), false);
});

test('CNPJ válido com dígito verificador correto', () => {
  assert.equal(isValidCNPJ('11.222.333/0001-81'), true);
  assert.equal(isValidCNPJ('11222333000181'), true);
});

test('CNPJ rejeitado: dígito verificador errado', () => {
  assert.equal(isValidCNPJ('11.222.333/0001-82'), false);
});

test('CNPJ rejeitado: todos os dígitos iguais', () => {
  assert.equal(isValidCNPJ('11.111.111/1111-11'), false);
});

test('isValidTaxId escolhe CPF ou CNPJ pela quantidade de dígitos', () => {
  assert.equal(isValidTaxId('111.444.777-35'), true);
  assert.equal(isValidTaxId('11.222.333/0001-81'), true);
  assert.equal(isValidTaxId('123456'), false);
});

test('formatCPF aplica máscara progressiva', () => {
  assert.equal(formatCPF('11144477735'), '111.444.777-35');
  assert.equal(formatCPF('111444'), '111.444');
});

test('formatCNPJ aplica máscara progressiva', () => {
  assert.equal(formatCNPJ('11222333000181'), '11.222.333/0001-81');
  assert.equal(formatCNPJ('112223'), '11.222.3');
});

test('formatTaxId decide CPF ou CNPJ pela quantidade de dígitos já digitados', () => {
  assert.equal(formatTaxId('11144477735'), '111.444.777-35');
  assert.equal(formatTaxId('11222333000181'), '11.222.333/0001-81');
});

test('formatPhone aplica máscara de celular e fixo', () => {
  assert.equal(formatPhone('11987654321'), '(11) 98765-4321');
  assert.equal(formatPhone('1132654321'), '(11) 3265-4321');
});

test('onlyDigits remove tudo que não é número', () => {
  assert.equal(onlyDigits('111.444.777-35'), '11144477735');
});
