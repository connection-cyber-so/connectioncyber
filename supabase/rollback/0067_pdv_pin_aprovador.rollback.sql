-- Rollback 0067. USO: laboratório descartável apenas. Após aplicação remota, prefira forward-fix (apps/portal/README.md).
-- Ordem obrigatória:
--   1) remover as assinaturas novas (com p_pin);
--   2) remover funções e tabela de PIN;
--   3) recriar as assinaturas de 0065 e 0066 (corpos em supabase/migrations/0065_... e 0066_...).
-- Sem o passo 3, as RPCs de desconto e de caixa somem do banco.

-- 1) Assinaturas novas
drop function if exists public.erp_authorize_discount(uuid, uuid, uuid, uuid, numeric, numeric, text, text);
drop function if exists public.erp_authorize_cash_action(uuid, uuid, text, numeric, uuid, text, text);

-- 2) PIN
drop function if exists public.erp_set_approver_pin(uuid, text, text);
drop function if exists public.erp_check_approver_pin(uuid, uuid, text);
drop table if exists public.erp_approver_pins;

-- 3) Recriar as versões anteriores:
--    - executar o bloco CREATE OR REPLACE FUNCTION de erp_authorize_discount em 0065_pdv_alcada_desconto_rpc.sql;
--    - executar o bloco CREATE OR REPLACE FUNCTION de erp_authorize_cash_action em 0066_pdv_alcada_caixa_sangria_fechamento.sql.
