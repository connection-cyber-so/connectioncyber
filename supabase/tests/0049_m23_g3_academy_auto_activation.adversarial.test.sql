begin;set local role postgres;create extension if not exists pgtap with schema extensions;set local search_path=public,extensions,pgtap;select plan(24);

-- Fixtures: F (capacidade + modulo ativo), G (sem capacidade; modulo suspenso),
-- H (sem grant; apenas exception allow). Slugs sinteticos: nunca dados reais.
insert into public.tenants (id,nome,slug,vertical,ativo) values
 ('95000000-0000-4000-8000-000000000001','M23G3 Tenant F','m23-g3-synthetic-f','varejo',true),
 ('95000000-0000-4000-8000-000000000002','M23G3 Tenant G','m23-g3-synthetic-g','servicos',true),
 ('95000000-0000-4000-8000-000000000003','M23G3 Tenant H','m23-g3-synthetic-h','varejo',true);
insert into public.erp_tenant_capabilities (tenant_id,capability_key,status,source,contract_version,evidence_hash) values
 ('95000000-0000-4000-8000-000000000001','academy.courses','active','migration',1,md5('m23g3f')||md5('cap'));
insert into public.tenant_modules (tenant_id,module_key,status) values
 ('95000000-0000-4000-8000-000000000001','treinamento-tecnologico','ativo'),
 ('95000000-0000-4000-8000-000000000002','treinamento-tecnologico','suspenso');

-- Aceite 1: curso publico so liga nas empresas com a chave academy.courses.
insert into public.academy_courses (id,tenant_id,titulo,escopo,publico,status)
 values ('96000000-0000-4000-8000-000000000001','95000000-0000-4000-8000-000000000001','G3 Publico','global',true,'publicado');
select is((select count(*) from public.academy_tenant_courses
  where course_id='96000000-0000-4000-8000-000000000001'
    and tenant_id in ('95000000-0000-4000-8000-000000000001','95000000-0000-4000-8000-000000000002','95000000-0000-4000-8000-000000000003')),1::bigint,
  'publico liga so as empresas com a chave');
select ok(exists(select 1 from public.academy_tenant_courses
  where tenant_id='95000000-0000-4000-8000-000000000001'
    and course_id='96000000-0000-4000-8000-000000000001'),'F (com chave) fica ligada');
select ok(not exists(select 1 from public.academy_tenant_courses
  where tenant_id='95000000-0000-4000-8000-000000000002'
    and course_id='96000000-0000-4000-8000-000000000001'),'G (sem chave) fica de fora');

-- Capacidade contratada: o gatilho de capacidade liga G sozinho.
insert into public.erp_tenant_capabilities (tenant_id,capability_key,status,source,contract_version,evidence_hash) values
 ('95000000-0000-4000-8000-000000000002','academy.courses','active','migration',1,md5('m23g3g')||md5('cap'));
select ok(exists(select 1 from public.academy_tenant_courses
  where tenant_id='95000000-0000-4000-8000-000000000002'
    and course_id='96000000-0000-4000-8000-000000000001'),
  'ligar a chave em G cria o vinculo sozinho');

-- Capacidade com janela vencida: o gatilho derruba F sem toque em ninguem.
update public.erp_tenant_capabilities set ends_at=now()-interval '1 day'
 where tenant_id='95000000-0000-4000-8000-000000000001' and capability_key='academy.courses';
select ok(not exists(select 1 from public.academy_tenant_courses
  where tenant_id='95000000-0000-4000-8000-000000000001'
    and course_id='96000000-0000-4000-8000-000000000001'),'janela vencida derruba F');
select ok(exists(select 1 from public.academy_tenant_courses
  where tenant_id='95000000-0000-4000-8000-000000000002'
    and course_id='96000000-0000-4000-8000-000000000001'),'G permanece ligada');
update public.erp_tenant_capabilities set ends_at=null
 where tenant_id='95000000-0000-4000-8000-000000000001' and capability_key='academy.courses';
select ok(exists(select 1 from public.academy_tenant_courses
  where tenant_id='95000000-0000-4000-8000-000000000001'
    and course_id='96000000-0000-4000-8000-000000000001'),'janela reaberta devolve F');

-- Exception deny vence o contrato na hora.
insert into public.erp_tenant_capability_exceptions
 (id,tenant_id,capability_key,effect,reason_hash,approval_ref,effective_from,expires_at,status)
 values ('97000000-0000-4000-8000-000000000001','95000000-0000-4000-8000-000000000001',
  'academy.courses','deny',md5('m23g3deny1')||md5('cap'),
  'approval:sha256:'||md5('m23g3deny1')||md5('ref'),
  now()-interval '1 day',now()+interval '1 day','active');
select ok(not exists(select 1 from public.academy_tenant_courses
  where tenant_id='95000000-0000-4000-8000-000000000001'
    and course_id='96000000-0000-4000-8000-000000000001'),'exception deny remove o vinculo na hora');
delete from public.erp_tenant_capability_exceptions where id='97000000-0000-4000-8000-000000000001';
select ok(exists(select 1 from public.academy_tenant_courses
  where tenant_id='95000000-0000-4000-8000-000000000001'
    and course_id='96000000-0000-4000-8000-000000000001'),'deny removida devolve F');

-- Exception allow liga empresa sem nenhum grant contratual.
insert into public.erp_tenant_capability_exceptions
 (id,tenant_id,capability_key,effect,reason_hash,approval_ref,effective_from,expires_at,status)
 values ('97000000-0000-4000-8000-000000000002','95000000-0000-4000-8000-000000000003',
  'academy.courses','allow',md5('m23g3allow')||md5('cap'),
  'approval:sha256:'||md5('m23g3allow')||md5('ref'),
  now()-interval '1 day',now()+interval '1 day','active');
select ok(exists(select 1 from public.academy_tenant_courses
  where tenant_id='95000000-0000-4000-8000-000000000003'
    and course_id='96000000-0000-4000-8000-000000000001'),
  'exception allow liga H sem capacidade contratada');

-- Aceite 2: alvo por sistema so nas empresas com o modulo ativo.
update public.academy_courses set publico=false, alvo_sistema='treinamento-tecnologico'
 where id='96000000-0000-4000-8000-000000000001';
select ok(exists(select 1 from public.academy_tenant_courses
  where tenant_id='95000000-0000-4000-8000-000000000001'
    and course_id='96000000-0000-4000-8000-000000000001'),
  'alvo por sistema liga a empresa que usa o modulo');
select ok(not exists(select 1 from public.academy_tenant_courses
  where tenant_id='95000000-0000-4000-8000-000000000002'
    and course_id='96000000-0000-4000-8000-000000000001'),
  'G usa o modulo mas esta suspenso e fica de fora');
select ok(not exists(select 1 from public.academy_tenant_courses
  where tenant_id='95000000-0000-4000-8000-000000000003'
    and course_id='96000000-0000-4000-8000-000000000001'),
  'H nao usa o modulo e fica de fora');
update public.tenant_modules set status='ativo'
 where tenant_id='95000000-0000-4000-8000-000000000002' and module_key='treinamento-tecnologico';
select ok(exists(select 1 from public.academy_tenant_courses
  where tenant_id='95000000-0000-4000-8000-000000000002'
    and course_id='96000000-0000-4000-8000-000000000001'),
  'ativar o modulo liga G pelo gatilho de tenant_modules');

-- Alvo por vertical: varejo liga F e H; servicos nao liga G.
update public.academy_courses set alvo_sistema=null, alvo_vertical='varejo'
 where id='96000000-0000-4000-8000-000000000001';
select ok(exists(select 1 from public.academy_tenant_courses
  where tenant_id='95000000-0000-4000-8000-000000000001'
    and course_id='96000000-0000-4000-8000-000000000001'),
  'alvo por vertical liga F (varejo)');
select ok(exists(select 1 from public.academy_tenant_courses
  where tenant_id='95000000-0000-4000-8000-000000000003'
    and course_id='96000000-0000-4000-8000-000000000001'),
  'alvo por vertical liga H (allow vigente)');
select ok(not exists(select 1 from public.academy_tenant_courses
  where tenant_id='95000000-0000-4000-8000-000000000002'
    and course_id='96000000-0000-4000-8000-000000000001'),
  'G (servicos) fica de fora da vertical varejo');

-- Idempotencia: recalculado no estado atual, nada muda.
select is((select public.academy_sync_links()),0::integer,'resync no estado atual nao muda nada');

-- Vinculo manual sobrevive a qualquer ressincronia.
insert into public.academy_tenant_courses (tenant_id,course_id,origem)
 values ('95000000-0000-4000-8000-000000000002','96000000-0000-4000-8000-000000000001','manual');
select ok(exists(select 1 from public.academy_tenant_courses
  where tenant_id='95000000-0000-4000-8000-000000000002'
    and course_id='96000000-0000-4000-8000-000000000001' and origem='manual'),
  'curador de G vincula na mao');
select public.academy_sync_links();
select ok(exists(select 1 from public.academy_tenant_courses
  where tenant_id='95000000-0000-4000-8000-000000000002'
    and course_id='96000000-0000-4000-8000-000000000001' and origem='manual'),
  'ressincronia preserva o vinculo manual');

-- Escopo tenant: dono sem chave sai (fail closed) e volta com a chave.
insert into public.academy_courses (id,tenant_id,titulo,escopo,publico,status)
 values ('96000000-0000-4000-8000-000000000002','95000000-0000-4000-8000-000000000001','G3 Do Tenant F','tenant',false,'publicado');
select ok(exists(select 1 from public.academy_tenant_courses
  where tenant_id='95000000-0000-4000-8000-000000000001'
    and course_id='96000000-0000-4000-8000-000000000002'),
  'curso do proprio tenant nasce ligado ao dono com chave');
insert into public.erp_tenant_capability_exceptions
 (id,tenant_id,capability_key,effect,reason_hash,approval_ref,effective_from,expires_at,status)
 values ('97000000-0000-4000-8000-000000000003','95000000-0000-4000-8000-000000000001',
  'academy.courses','deny',md5('m23g3deny2')||md5('cap'),
  'approval:sha256:'||md5('m23g3deny2')||md5('ref'),
  now()-interval '1 day',now()+interval '1 day','active');
select ok(not exists(select 1 from public.academy_tenant_courses
  where tenant_id='95000000-0000-4000-8000-000000000001'
    and course_id='96000000-0000-4000-8000-000000000002'),
  'dono perde a chave e o vinculo proprio sai');
delete from public.erp_tenant_capability_exceptions where id='97000000-0000-4000-8000-000000000003';
select ok(exists(select 1 from public.academy_tenant_courses
  where tenant_id='95000000-0000-4000-8000-000000000001'
    and course_id='96000000-0000-4000-8000-000000000002'),
  'chave de volta devolve o vinculo do dono');
select ok(exists(select 1 from public.academy_tenant_courses
  where tenant_id='95000000-0000-4000-8000-000000000002'
    and course_id='96000000-0000-4000-8000-000000000001' and origem='manual'),
  'manual de G atravessa todos os ciclos de capacidade');

select * from finish();
rollback;
