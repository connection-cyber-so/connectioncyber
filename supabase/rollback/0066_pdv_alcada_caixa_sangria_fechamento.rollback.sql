-- Rollback 0066. USO: laboratório descartável apenas. Após aplicação remota, prefira forward-fix (apps/portal/README.md).
-- Ordem obrigatória: (1) restaurar erp_command_close_cash_v1 ao corpo original de
--   supabase/migrations/0033_m17_persistent_journey.sql, (2) só então remover helpers e tabela.
-- Sem o passo 1, o fechamento passa a chamar erp_assert_cash_close_authorized_v1 já removida e falha.

-- 1) Restaurar erp_command_close_cash_v1: executar o bloco CREATE OR REPLACE FUNCTION de 0033_m17_persistent_journey.sql.

-- 2) Remover trigger e funções novas
drop trigger if exists erp_cash_movements_guard_trg on public.erp_cash_movements;
drop function if exists public.erp_cash_movements_guard_v1();
drop function if exists public.erp_assert_cash_close_authorized_v1(uuid, uuid, numeric, numeric, uuid);
drop function if exists public.erp_authorize_cash_action(uuid, uuid, text, numeric, uuid, text);
drop function if exists public.erp_cash_session_expected_v1(uuid, uuid);

-- 3) Remover vínculos e índices
drop index if exists public.erp_cash_sessions_closing_authorization_key;
alter table public.erp_cash_sessions drop constraint if exists erp_cash_sessions_closing_authorization_fk;
alter table public.erp_cash_sessions drop column if exists closing_authorization_id;
drop index if exists public.erp_cash_movements_authorization_key;
alter table public.erp_cash_movements drop constraint if exists erp_cash_movements_authorization_fk;
alter table public.erp_cash_movements drop column if exists authorization_id;

-- 4) Remover tabela de autorizações
drop table if exists public.erp_cash_authorizations;

-- 5) Remover o limite padrão semeado pela 0066
delete from public.erp_tenant_settings where key = 'pdv.cash.withdrawal_limit_amount' and establishment_id is null;
