begin;set local role postgres;create extension if not exists pgtap with schema extensions;set local search_path=public,extensions,pgtap;select plan(25);
select set_config('request.jwt.claim.role','service_role',true);

-- Fixtures: tenant C (capacidade + alvo), tenant D (capacidade), tenant E (sem capacidade).
insert into public.tenants (id,nome,slug,vertical,ativo) values
 ('92000000-0000-4000-8000-000000000001','M23G2 Tenant C','m23-g2-synthetic-c','varejo',true),
 ('92000000-0000-4000-8000-000000000002','M23G2 Tenant D','m23-g2-synthetic-d','servicos',true),
 ('92000000-0000-4000-8000-000000000003','M23G2 Tenant E','m23-g2-synthetic-e','servicos',true);
insert into auth.users (id,aud,role,email,encrypted_password,raw_app_meta_data,raw_user_meta_data,created_at,updated_at) values
 ('93000000-0000-4000-8000-000000000001','authenticated','authenticated','m23-g2-staff@example.invalid','','{"provider":"email","providers":["email"]}','{"full_name":"M23G2 Staff","tenant_id":"92000000-0000-4000-8000-000000000001"}',now(),now()),
 ('93000000-0000-4000-8000-000000000002','authenticated','authenticated','m23-g2-curador-c@example.invalid','','{"provider":"email","providers":["email"]}','{"full_name":"M23G2 Curador C","tenant_id":"92000000-0000-4000-8000-000000000001"}',now(),now()),
 ('93000000-0000-4000-8000-000000000003','authenticated','authenticated','m23-g2-aluno-c@example.invalid','','{"provider":"email","providers":["email"]}','{"full_name":"M23G2 Aluno C","tenant_id":"92000000-0000-4000-8000-000000000001"}',now(),now()),
 ('93000000-0000-4000-8000-000000000004','authenticated','authenticated','m23-g2-curador-d@example.invalid','','{"provider":"email","providers":["email"]}','{"full_name":"M23G2 Curador D","tenant_id":"92000000-0000-4000-8000-000000000002"}',now(),now()),
 ('93000000-0000-4000-8000-000000000005','authenticated','authenticated','m23-g2-aluno-d@example.invalid','','{"provider":"email","providers":["email"]}','{"full_name":"M23G2 Aluno D","tenant_id":"92000000-0000-4000-8000-000000000002"}',now(),now()),
 ('93000000-0000-4000-8000-000000000006','authenticated','authenticated','m23-g2-aluno-e@example.invalid','','{"provider":"email","providers":["email"]}','{"full_name":"M23G2 Aluno E","tenant_id":"92000000-0000-4000-8000-000000000003"}',now(),now());
insert into public.users (id,nome,email,tenant_id) values
 ('93000000-0000-4000-8000-000000000001','M23G2 Staff','m23-g2-staff@example.invalid',null),
 ('93000000-0000-4000-8000-000000000002','M23G2 Curador C','m23-g2-curador-c@example.invalid',null),
 ('93000000-0000-4000-8000-000000000003','M23G2 Aluno C','m23-g2-aluno-c@example.invalid',null),
 ('93000000-0000-4000-8000-000000000004','M23G2 Curador D','m23-g2-curador-d@example.invalid',null),
 ('93000000-0000-4000-8000-000000000005','M23G2 Aluno D','m23-g2-aluno-d@example.invalid',null),
 ('93000000-0000-4000-8000-000000000006','M23G2 Aluno E','m23-g2-aluno-e@example.invalid',null)
 on conflict (id) do nothing;
insert into public.erp_tenant_memberships (id,tenant_id,user_id,status,is_default) values
 ('a2000000-0000-4000-8000-000000000001','92000000-0000-4000-8000-000000000001','93000000-0000-4000-8000-000000000001','active',true),
 ('a2000000-0000-4000-8000-000000000002','92000000-0000-4000-8000-000000000001','93000000-0000-4000-8000-000000000002','active',false),
 ('a2000000-0000-4000-8000-000000000003','92000000-0000-4000-8000-000000000001','93000000-0000-4000-8000-000000000003','active',false),
 ('a2000000-0000-4000-8000-000000000004','92000000-0000-4000-8000-000000000002','93000000-0000-4000-8000-000000000004','active',true),
 ('a2000000-0000-4000-8000-000000000005','92000000-0000-4000-8000-000000000002','93000000-0000-4000-8000-000000000005','active',false),
 ('a2000000-0000-4000-8000-000000000006','92000000-0000-4000-8000-000000000003','93000000-0000-4000-8000-000000000006','active',true)
 on conflict (tenant_id,user_id) do nothing;
insert into public.erp_roles (id,tenant_id,key,name) values
 ('b2000000-0000-4000-8000-000000000001','92000000-0000-4000-8000-000000000001','instructor','Instrutor M23G2 C'),
 ('b2000000-0000-4000-8000-000000000002','92000000-0000-4000-8000-000000000002','instructor','Instrutor M23G2 D');
insert into public.erp_role_permissions (tenant_id,role_id,permission_id)
 select r.tenant_id,r.id,p.id from public.erp_roles r
 cross join public.erp_permissions p
 where r.key='instructor' and p.key='academy.manage'
   and r.tenant_id in ('92000000-0000-4000-8000-000000000001','92000000-0000-4000-8000-000000000002');
insert into public.erp_membership_roles (tenant_id,membership_id,role_id) values
 ('92000000-0000-4000-8000-000000000001','a2000000-0000-4000-8000-000000000002','b2000000-0000-4000-8000-000000000001'),
 ('92000000-0000-4000-8000-000000000002','a2000000-0000-4000-8000-000000000004','b2000000-0000-4000-8000-000000000002');
insert into public.erp_tenant_capabilities (tenant_id,capability_key,status,source,contract_version,evidence_hash) values
 ('92000000-0000-4000-8000-000000000001','academy.courses','active','migration',1,md5('m23g2c')||md5('cap')),
 ('92000000-0000-4000-8000-000000000002','academy.courses','active','migration',1,md5('m23g2d')||md5('cap'));
insert into public.roles (id,nome) values ('94000000-0000-4000-8000-000000000001','admin') on conflict (nome) do nothing;
insert into public.user_roles (user_id,role_id)
 select '93000000-0000-4000-8000-000000000001',id from public.roles where nome='admin'
 on conflict do nothing;
insert into public.tenant_modules (tenant_id,module_key,status)
 values ('92000000-0000-4000-8000-000000000001','treinamento-tecnologico','ativo');

create temporary table m23g2_course (r jsonb);
create temporary table m23g2_local (r jsonb);
create temporary table m23g2_module (r jsonb);
grant all on m23g2_course,m23g2_local,m23g2_module to authenticated;

-- Sessao do staff de plataforma (role publica admin + membership em C).
set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','93000000-0000-4000-8000-000000000001',true);
select set_config('request.jwt.claims','{"sub":"93000000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal1"}',true);
select set_config('request.jwt.claim.aal','aal1',true);

select throws_ok($$select public.academy_command('92000000-0000-4000-8000-000000000001','create_course',null,'{"titulo":"Global Sem Alvo","escopo":"global","publico":false}'::jsonb)$$,'22023','ACADEMY_GLOBAL_TARGET_REQUIRED','global sem publico e sem alvo rejeitado');
insert into m23g2_course select public.academy_command('92000000-0000-4000-8000-000000000001','create_course',null,'{"titulo":"Curso Global M23G2","descricao":"Catalogo para todos","escopo":"global"}'::jsonb);
select is((select r->>'escopo' from m23g2_course),'global','staff cria curso global');
select is((select r->>'publico' from m23g2_course),'true','curso global nasce ligado para todos');
select is((select count(*) from public.academy_tenant_courses
  where course_id=(select (r->>'id')::uuid from m23g2_course)
    and tenant_id in ('92000000-0000-4000-8000-000000000001','92000000-0000-4000-8000-000000000002','92000000-0000-4000-8000-000000000003')),3::bigint,'sincronia liga as 3 empresas dos fixtures');
insert into m23g2_module select public.academy_command('92000000-0000-4000-8000-000000000001','add_module',
 (select (r->>'id')::uuid from m23g2_course),'{"titulo":"Aula 1 - Introducao","tipo":"video","duracao_min":10}'::jsonb);
select is((select r->>'tenant_id' from m23g2_module),'92000000-0000-4000-8000-000000000001','modulo nasce no dono do curso, nao na empresa chamadora');
select is((select (public.academy_command('92000000-0000-4000-8000-000000000001','publish_course',
  (select (r->>'id')::uuid from m23g2_course),'{"status":"publicado"}'::jsonb))->>'status'),'publicado','staff publica o global');

-- Aluno de D (empresa com capacidade): matricula e progride em curso de outra empresa.
select set_config('request.jwt.claim.sub','93000000-0000-4000-8000-000000000005',true);
select set_config('request.jwt.claims','{"sub":"93000000-0000-4000-8000-000000000005","role":"authenticated","aal":"aal1"}',true);
select public.academy_command('92000000-0000-4000-8000-000000000002','enroll',(select (r->>'id')::uuid from m23g2_course),'{}'::jsonb);
select is((select count(*) from public.academy_enrollments
  where tenant_id='92000000-0000-4000-8000-000000000002' and user_id='93000000-0000-4000-8000-000000000005'
  and course_id=(select (r->>'id')::uuid from m23g2_course)),1::bigint,'matricula do aluno D no global');
select public.academy_command('92000000-0000-4000-8000-000000000002','complete_module',null,
 jsonb_build_object('module_id',(select (r->>'id')::uuid from m23g2_module)));
select is((select progresso from public.academy_enrollments
  where tenant_id='92000000-0000-4000-8000-000000000002' and user_id='93000000-0000-4000-8000-000000000005'
  and course_id=(select (r->>'id')::uuid from m23g2_course)),100::numeric,'progresso cruza empresas (modulo do dono, progresso de D)');

-- Aluno de E (sem capacidade contratada): fail closed.
select set_config('request.jwt.claim.sub','93000000-0000-4000-8000-000000000006',true);
select set_config('request.jwt.claims','{"sub":"93000000-0000-4000-8000-000000000006","role":"authenticated","aal":"aal1"}',true);
select throws_ok($$select public.academy_command('92000000-0000-4000-8000-000000000003','enroll',(select (r->>'id')::uuid from m23g2_course),'{}'::jsonb)$$,'42501','ACADEMY_ACCESS_DENIED','empresa sem capacidade nao matricula');
select is((select count(*) from public.academy_courses),0::bigint,'empresa sem capacidade nao enxerga cursos');

-- Curador de C: nao cria global, nao mexe em alvo nem em vinculo alheio de regra.
select set_config('request.jwt.claim.sub','93000000-0000-4000-8000-000000000002',true);
select set_config('request.jwt.claims','{"sub":"93000000-0000-4000-8000-000000000002","role":"authenticated","aal":"aal1"}',true);
select throws_ok($$select public.academy_command('92000000-0000-4000-8000-000000000001','create_course',null,'{"titulo":"Global Do Curador","escopo":"global"}'::jsonb)$$,'42501','ACADEMY_PLATFORM_REQUIRED','curador comum nao cria curso global');
insert into m23g2_local select public.academy_command('92000000-0000-4000-8000-000000000001','create_course',null,'{"titulo":"Curso Do Tenant C"}'::jsonb);
select is((select r->>'titulo' from m23g2_local),'Curso Do Tenant C','curador cria curso do proprio tenant');
select throws_ok($$select public.academy_command('92000000-0000-4000-8000-000000000001','link_course',(select (r->>'id')::uuid from m23g2_local),'{}'::jsonb)$$,'42501','ACADEMY_LINK_ONLY_GLOBAL','vinculo manual so existe para curso global');
select throws_ok($$select public.academy_command('92000000-0000-4000-8000-000000000001','unlink_course',(select (r->>'id')::uuid from m23g2_course),'{}'::jsonb)$$,'42501','ACADEMY_LINK_AUTO','vinculo automatico nao e removivel na mao');
select throws_ok($$select public.academy_command('92000000-0000-4000-8000-000000000001','set_course_targets',(select (r->>'id')::uuid from m23g2_course),'{"publico":false,"alvo_sistema":"assessoria-tecnica"}'::jsonb)$$,'42501','ACADEMY_PLATFORM_REQUIRED','so a plataforma mexe em alvo de curso global');

-- Staff restringe o alvo: publico=false + sistema; sincronia reencaixa so em C.
select set_config('request.jwt.claim.sub','93000000-0000-4000-8000-000000000001',true);
select set_config('request.jwt.claims','{"sub":"93000000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal1"}',true);
select is((select (public.academy_command('92000000-0000-4000-8000-000000000001','set_course_targets',
  (select (r->>'id')::uuid from m23g2_course),
  '{"publico":false,"alvo_sistema":"treinamento-tecnologico"}'::jsonb))->>'publico'),'false','staff troca o alvo do global');
select is((select count(*) from public.academy_tenant_courses
  where course_id=(select (r->>'id')::uuid from m23g2_course)
    and tenant_id in ('92000000-0000-4000-8000-000000000001','92000000-0000-4000-8000-000000000002','92000000-0000-4000-8000-000000000003')),1::bigint,'alvo por sistema reencaixa so na empresa que usa o modulo');
select is((select count(*) from public.academy_enrollments
  where tenant_id='92000000-0000-4000-8000-000000000002'
  and course_id=(select (r->>'id')::uuid from m23g2_course)),1::bigint,'matricula de D sobrevive ao reencaixe do vinculo');

-- Curador de D: vincula na mao (manual), aluno passa a ver; desvincula; some de novo.
select set_config('request.jwt.claim.sub','93000000-0000-4000-8000-000000000004',true);
select set_config('request.jwt.claims','{"sub":"93000000-0000-4000-8000-000000000004","role":"authenticated","aal":"aal1"}',true);
select public.academy_command('92000000-0000-4000-8000-000000000002','link_course',(select (r->>'id')::uuid from m23g2_course),'{}'::jsonb);
select is((select origem from public.academy_tenant_courses
  where tenant_id='92000000-0000-4000-8000-000000000002'
  and course_id=(select (r->>'id')::uuid from m23g2_course)),'manual','curador de D vincula manualmente');
select set_config('request.jwt.claim.sub','93000000-0000-4000-8000-000000000005',true);
select set_config('request.jwt.claims','{"sub":"93000000-0000-4000-8000-000000000005","role":"authenticated","aal":"aal1"}',true);
select is((select count(*) from public.academy_courses
  where id=(select (r->>'id')::uuid from m23g2_course)),1::bigint,'vinculo manual revela o curso para o aluno de D');
select set_config('request.jwt.claim.sub','93000000-0000-4000-8000-000000000004',true);
select set_config('request.jwt.claims','{"sub":"93000000-0000-4000-8000-000000000004","role":"authenticated","aal":"aal1"}',true);
select public.academy_command('92000000-0000-4000-8000-000000000002','unlink_course',(select (r->>'id')::uuid from m23g2_course),'{}'::jsonb);
select is((select count(*) from public.academy_tenant_courses
  where tenant_id='92000000-0000-4000-8000-000000000002'
  and course_id=(select (r->>'id')::uuid from m23g2_course)),0::bigint,'desvincular manual e a regra nao recria (D nao usa o modulo)');
select throws_ok($$select public.academy_command('92000000-0000-4000-8000-000000000002','unlink_course',(select (r->>'id')::uuid from m23g2_course),'{}'::jsonb)$$,'42501','ACADEMY_COURSE_NOT_LINKED','desvincular sem vinculo rejeitado');
select set_config('request.jwt.claim.sub','93000000-0000-4000-8000-000000000005',true);
select set_config('request.jwt.claims','{"sub":"93000000-0000-4000-8000-000000000005","role":"authenticated","aal":"aal1"}',true);
select is((select count(*) from public.academy_courses),0::bigint,'sem vinculo o catalogo de D volta a ficar vazio');

-- Isolamento e sem DML direto.
select set_config('request.jwt.claim.sub','93000000-0000-4000-8000-000000000003',true);
select set_config('request.jwt.claims','{"sub":"93000000-0000-4000-8000-000000000003","role":"authenticated","aal":"aal1"}',true);
do $$ declare hit boolean:=false; begin
 begin
  update public.academy_tenant_courses set ativo=false where tenant_id='92000000-0000-4000-8000-000000000001';
 exception when insufficient_privilege then hit:=true;
 end;
 if not hit then raise exception 'M23_G2: authenticated escreveu em academy_tenant_courses'; end if;
end $$;
select ok(true,'authenticated nao escreve academy_tenant_courses diretamente');
select is((select count(*) from public.academy_courses),2::bigint,'aluno de C ve o global alvo + o curso do proprio tenant');

select * from finish();
rollback;
