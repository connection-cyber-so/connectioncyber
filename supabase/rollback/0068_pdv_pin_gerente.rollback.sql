-- ROLLBACK 0068 · PDV · PIN cadastrado pelo gerente
-- Efeito: remove erp_manager_set_approver_pin e recria o autoatendimento de PIN da 0067.
-- Não altera dados: erp_approver_pins e os PINs cadastrados permanecem.
-- Uso preferencial: forward-fix (aplicado no staging). Este script serve a laboratório ou reversão controlada.
-- Corpo de erp_set_approver_pin copiado de supabase/migrations/0067_pdv_pin_aprovador.sql.

begin;

drop function if exists public.erp_manager_set_approver_pin(uuid, uuid, text);

create or replace function public.erp_set_approver_pin(p_tenant_id uuid, p_new_pin text, p_current_pin text default null)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := (select auth.uid());
  v_status text;
begin
  if v_user is null then
    raise exception 'erp_set_approver_pin: sessao autenticada obrigatoria' using errcode = '42501';
  end if;

  if p_new_pin is null or p_new_pin !~ '^[0-9]{4,6}$' then
    raise exception 'erp_set_approver_pin: PIN deve ter de 4 a 6 digitos' using errcode = '22023';
  end if;

  if not (select erp_security.has_permission(p_tenant_id, 'sales.discount')
          or erp_security.has_permission(p_tenant_id, 'cash.adjust')
          or erp_security.has_permission(p_tenant_id, 'cash.close')) then
    raise exception 'erp_set_approver_pin: usuario sem permissao de alcada' using errcode = '42501';
  end if;

  if exists (select 1 from public.erp_approver_pins where tenant_id = p_tenant_id and user_id = v_user) then
    v_status := public.erp_check_approver_pin(p_tenant_id, v_user, p_current_pin);
    if v_status <> 'ok' then
      return v_status;
    end if;
  end if;

  insert into public.erp_approver_pins (tenant_id, user_id, pin_hash, failed_attempts, locked_until, updated_at)
  values (p_tenant_id, v_user, extensions.crypt(p_new_pin, extensions.gen_salt('bf')), 0, null, now())
  on conflict (tenant_id, user_id) do update
    set pin_hash = excluded.pin_hash, failed_attempts = 0, locked_until = null, updated_at = now();

  return 'ok';
end;
$$;

revoke all on function public.erp_set_approver_pin(uuid, text, text) from public, anon;
grant execute on function public.erp_set_approver_pin(uuid, text, text) to authenticated;

-- Conferência antes do commit: a função de gerente não existe mais e a de autoatendimento voltou.
do $$
begin
  if to_regprocedure('public.erp_manager_set_approver_pin(uuid,uuid,text)') is not null then
    raise exception 'ROLLBACK 0068 FALHOU: erp_manager_set_approver_pin ainda existe';
  end if;
  if to_regprocedure('public.erp_set_approver_pin(uuid,text,text)') is null then
    raise exception 'ROLLBACK 0068 FALHOU: erp_set_approver_pin não foi recriada';
  end if;
end
$$;

commit;
