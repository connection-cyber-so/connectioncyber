-- PREFLIGHT 0068 · PDV · PIN cadastrado pelo gerente
-- Somente leitura. Rodar ANTES de aplicar 0068 (estado 0067) ou antes de um rollback do 0068.
-- Cada bloco lança exceção se a pré-condição faltar; sem exceção = pronto.
-- Atenção: depois da aplicação do 0068, o item 4 deve falhar (função de autoatendimento removida).
-- Isso é esperado e não é erro do 0068.

do $$
declare
  v_missing text;
begin
  -- 1) Dependências do 0067
  if to_regclass('public.erp_approver_pins') is null then
    raise exception 'PREFLIGHT 1 FALHOU: tabela erp_approver_pins ausente (aplicar 0067 antes)';
  end if;
  if to_regprocedure('public.erp_check_approver_pin(uuid,uuid,text)') is null then
    raise exception 'PREFLIGHT 1 FALHOU: erp_check_approver_pin ausente (aplicar 0067 antes)';
  end if;

  -- 2) Extensão de hash (pgcrypto no schema extensions)
  if to_regprocedure('extensions.crypt(text,text)') is null
     or to_regprocedure('extensions.gen_salt(text)') is null then
    raise exception 'PREFLIGHT 2 FALHOU: extensions.crypt / extensions.gen_salt ausentes';
  end if;

  -- 3) Modelo de permissões usado pela checagem de gerente e de alçada
  if to_regprocedure('erp_security.has_permission(uuid,text)') is null then
    raise exception 'PREFLIGHT 3 FALHOU: erp_security.has_permission ausente';
  end if;
  if to_regprocedure('public.is_platform_staff()') is null then
    raise exception 'PREFLIGHT 3 FALHOU: public.is_platform_staff ausente';
  end if;
  if to_regclass('public.erp_membership_roles') is null
     or to_regclass('public.erp_role_permissions') is null
     or to_regclass('public.erp_permissions') is null then
    raise exception 'PREFLIGHT 3 FALHOU: tabelas de papel/permissão ausentes';
  end if;

  -- 4) Estado anterior à 0068: autoatendimento ainda existe
  if to_regprocedure('public.erp_set_approver_pin(uuid,text,text)') is null then
    raise notice 'PREFLIGHT 4: erp_set_approver_pin já não existe (0068 aplicada ou rollback já feito)';
  end if;

  -- 5) Chaves de permissão exigidas
  select string_agg(k, ', ') into v_missing
    from unnest(array['memberships.manage', 'sales.discount', 'cash.adjust', 'cash.close']) as k
   where not exists (select 1 from public.erp_permissions p where p.key = k);
  if v_missing is not null then
    raise exception 'PREFLIGHT 5 FALHOU: permissões ausentes: %', v_missing;
  end if;

  -- 6) Nenhuma função de PIN exposta a anon
  if has_function_privilege('anon', 'public.erp_check_approver_pin(uuid,uuid,text)', 'EXECUTE') then
    raise exception 'PREFLIGHT 6 FALHOU: anon com EXECUTE em erp_check_approver_pin';
  end if;

  raise notice 'PREFLIGHT 0068 OK (itens 1, 2, 3, 5, 6)';
end
$$;
