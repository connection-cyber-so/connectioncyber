-- 0056 teste. Tudo dentro de transação com ROLLBACK: não deixa dado.
-- Dados de teste marcados FICTICIO. Rodar só em staging, depois de aplicar a 0056.
begin;

do $$
declare
  v_tenant uuid := '00000000-0000-0000-0000-000000000001';
  v_erro text;
begin
  -- 1. Catálogo com as 3 chaves
  if (select count(*) from public.erp_capability_catalog where key in ('cd.armazenagem', 'cd.expedicao', 'site.loja')) <> 3 then
    raise exception 'FALHOU 1: catálogo sem as 3 chaves';
  end if;

  -- 2. Dependências esperadas (4 arestas)
  if (select count(*) from public.erp_capability_dependencies) <> 4 then
    raise exception 'FALHOU 2: dependências diferentes de 4';
  end if;

  -- 3. Nuvem com as 3 capacidades ativas e evidence_hash válido
  if (select count(*) from public.erp_tenant_capabilities
      where tenant_id = v_tenant and capability_key in ('cd.armazenagem', 'cd.expedicao', 'site.loja')
        and status = 'active' and evidence_hash ~ '^[a-f0-9]{64}$') <> 3 then
    raise exception 'FALHOU 3: vínculos da Nuvem ausentes';
  end if;

  -- 4. Suspender armazenagem e tentar ativar expedição deve falhar (fail-closed)
  update public.erp_tenant_capabilities set status = 'suspended'
    where tenant_id = v_tenant and capability_key = 'cd.armazenagem';
  begin
    update public.erp_tenant_capabilities set status = 'trial'
      where tenant_id = v_tenant and capability_key = 'cd.expedicao';
    raise exception 'FALHOU 4: expedição aceita com armazenagem suspensa';
  exception when check_violation then
    null;
  end;

  -- 5. Desativar (disabled) dependência não bloqueia a própria escrita de 'disabled'
  update public.erp_tenant_capabilities set status = 'disabled'
    where tenant_id = v_tenant and capability_key = 'cd.expedicao';

  -- 6. Chave sem dependência cadastrada ('migration') continua aceitando escrita de status
  update public.erp_tenant_capabilities set status = 'active'
    where tenant_id = v_tenant and capability_key = 'migration';

  raise notice 'OK 0056: 6 de 6 verificações passaram';
end $$;

rollback;
