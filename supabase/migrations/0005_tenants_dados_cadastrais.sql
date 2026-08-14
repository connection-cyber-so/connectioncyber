-- =========================================================================
-- ConnectionCyberSO — Enriquecimento cadastral de tenants
-- (docs/metodologia-povoamento-tenant-cnpj-cnae.md)
--
-- Mesmo padrão validado em bpo-system-web-os (bpo_clients): guarda o CNPJ e
-- os dados públicos da Receita Federal (via nossa Edge Function lookup-cnpj)
-- direto na tabela tenants, em vez de uma tabela separada — cliente novo
-- (Opção A) continua sendo uma linha em tenants, agora com dado cadastral
-- real quando disponível.
-- =========================================================================

alter table public.tenants
  add column if not exists cnpj                text unique,
  add column if not exists razao_social         text,
  add column if not exists cnae_principal       text,
  add column if not exists cnae_descricao       text,
  add column if not exists porte_receita        text,
  add column if not exists situacao_cadastral   text,
  add column if not exists municipio            text,
  add column if not exists uf                   text,
  add column if not exists data_abertura        date,
  add column if not exists natureza_juridica    text,
  add column if not exists dados_receita_raw    jsonb;

comment on column public.tenants.cnpj is
  'CNPJ do tenant (registro público). Preenchido via Edge Function lookup-cnpj no onboarding.';
comment on column public.tenants.dados_receita_raw is
  'Resposta bruta da consulta à Receita Federal (via BrasilAPI) — evita nova migration a cada campo adicional que se tornar útil.';

create index if not exists idx_tenants_cnpj on public.tenants (cnpj);
