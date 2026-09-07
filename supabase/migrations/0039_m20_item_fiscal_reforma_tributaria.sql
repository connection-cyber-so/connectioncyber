-- ConnectionCyber — M20-G5: colunas do IBS/CBS (reforma tributária, LC 214/2025)
-- em erp_item_fiscal_data.
--
-- Fonte: schema oficial da SEFAZ já fixado no projeto
-- (packages/fiscal-contract/schemas/nfe/010e_v1.02/xsd/PL_010e_v1.02/NFe/
-- DFeTiposBasicos_v1.00.xsd), não é campo inventado — os tipos TCST (CST do
-- IBS/CBS, 3 dígitos) e TcClassTrib (Código de Classificação Tributária,
-- 6 dígitos) já existem no pacote XSD, dentro de TTribNFCe/TTribNFe
-- ("Grupo de informações dos tributos IBS, CBS e Imposto Seletivo").
--
-- Deliberadamente NÃO adicionado nesta migration: alíquotas/valores de
-- IBS/CBS (pIBSUF/pIBSMun/pCBS/vIBS/vCBS) e o grupo de Imposto Seletivo
-- (CSTIS/cClassTribIS/pIS) — 2026 é fase de teste com alíquotas simbólicas
-- ainda em ajuste, e a tabela oficial de códigos de cClassTrib (o que cada
-- um dos 6 dígitos significa) é anexo separado da LC 214/25, não vem no XSD
-- estrutural — mesma regra que já vale pra NCM/CSOSN hoje: aguarda
-- confirmação do contador antes de ligar isso pra valer. Este portão só
-- abre espaço pros dois códigos identificadores, sem forçar preenchimento.
begin;

alter table public.erp_item_fiscal_data
  add column cst_ibs_cbs text check (cst_ibs_cbs is null or cst_ibs_cbs ~ '^[0-9]{3}$'),
  add column cclass_trib text check (cclass_trib is null or cclass_trib ~ '^[0-9]{6}$');

comment on column public.erp_item_fiscal_data.cst_ibs_cbs is
  'CST do IBS/CBS (reforma tributária, LC 214/2025) — 3 dígitos, paralelo e distinto do CST/CSOSN do ICMS já existente na mesma linha.';
comment on column public.erp_item_fiscal_data.cclass_trib is
  'Código de Classificação Tributária do IBS/CBS (reforma tributária, LC 214/2025) — 6 dígitos, conforme tabela oficial anexa à LC 214/25.';

commit;
