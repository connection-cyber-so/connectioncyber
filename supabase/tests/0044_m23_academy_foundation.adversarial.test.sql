begin;set local role postgres;create extension if not exists pgtap with schema extensions;set local search_path=public,extensions,pgtap;select plan(14);
select set_config('request.jwt.claim.role','service_role',true);

-- Fixtures sintéticos: dois tenants, aluno, curador e membro de outro tenant.
insert into public.tenants (id,nome,slug,vertical,ativo) values
 ('90000000-0000-4000-8000-000000000001','M23 Tenant A','m23-g0-synthetic-a','varejo',true),
 ('90000000-0000-4000-8000-000000000002','M23 Tenant B','m23-g0-synthetic-b','varejo',true);
insert into auth.users (id,aud,role,email,encrypted_password,raw_app_meta_data,raw_user_meta_data,created_at,updated_at) values
 ('91000000-0000-4000-8000-000000000001','authenticated','authenticated','m23-g0-aluno@example.invalid','','{"provider":"email","providers":["email"]}','{"full_name":"M23 Aluno","tenant_id":"90000000-0000-4000-8000-000000000001"}',now(),now()),
 ('91000000-0000-4000-8000-000000000002','authenticated','authenticated','m23-g0-curador@example.invalid','','{"provider":"email","providers":["email"]}','{"full_name":"M23 Curador","tenant_id":"90000000-0000-4000-8000-000000000001"}',now(),now()),
 ('91000000-0000-4000-8000-000000000003','authenticated','authenticated','m23-g0-outro@example.invalid','','{"provider":"email","providers":["email"]}','{"full_name":"M23 Outro Tenant","tenant_id":"90000000-0000-4000-8000-000000000002"}',now(),now());
insert into public.users (id,nome,email,tenant_id) values
 ('91000000-0000-4000-8000-000000000001','M23 Aluno','m23-g0-aluno@example.invalid','90000000-0000-4000-8000-000000000001'),
 ('91000000-0000-4000-8000-000000000002','M23 Curador','m23-g0-curador@example.invalid','90000000-0000-4000-8000-000000000001'),
 ('91000000-0000-4000-8000-000000000003','M23 Outro Tenant','m23-g0-outro@example.invalid','90000000-0000-4000-8000-000000000002')
 on conflict (id) do nothing;
insert into public.erp_tenant_memberships (id,tenant_id,user_id,status,is_default) values
 ('a1000000-0000-4000-8000-000000000001','90000000-0000-4000-8000-000000000001','91000000-0000-4000-8000-000000000001','active',true),
 ('a1000000-0000-4000-8000-000000000002','90000000-0000-4000-8000-000000000001','91000000-0000-4000-8000-000000000002','active',false),
 ('a1000000-0000-4000-8000-000000000003','90000000-0000-4000-8000-000000000002','91000000-0000-4000-8000-000000000003','active',true);
insert into public.erp_roles (id,tenant_id,key,name) values
 ('b1000000-0000-4000-8000-000000000001','90000000-0000-4000-8000-000000000001','instructor','Instrutor M23');
insert into public.erp_role_permissions (tenant_id,role_id,permission_id)
 select '90000000-0000-4000-8000-000000000001','b1000000-0000-4000-8000-000000000001',id
 from public.erp_permissions where key='academy.manage';
insert into public.erp_membership_roles (tenant_id,membership_id,role_id)
 values ('90000000-0000-4000-8000-000000000001','a1000000-0000-4000-8000-000000000002','b1000000-0000-4000-8000-000000000001');
insert into public.erp_tenant_capabilities (tenant_id,capability_key,status,source,contract_version,evidence_hash)
 values ('90000000-0000-4000-8000-000000000001','academy.courses','active','migration',1,md5('m23g0')||md5('academy'));

create temporary table m23g0_course (r jsonb);
create temporary table m23g0_module (r jsonb);
grant all on m23g0_course,m23g0_module to authenticated;

-- Sessão do curador (sem MFA forçado: academy.manage aceita AAL1).
set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','91000000-0000-4000-8000-000000000002',true);
select set_config('request.jwt.claims','{"sub":"91000000-0000-4000-8000-000000000002","role":"authenticated","aal":"aal1"}',true);
select set_config('request.jwt.claim.aal','aal1',true);

insert into m23g0_course select public.academy_command('90000000-0000-4000-8000-000000000001','create_course',null,
 '{"titulo":"Curso M23 Fundamentos","descricao":"Base da academia"}'::jsonb);
select is((select r->>'titulo' from m23g0_course),'Curso M23 Fundamentos','curador cria curso');

-- Aluno (mesmo tenant, sem academy.manage) não pode criar curso.
select set_config('request.jwt.claim.sub','91000000-0000-4000-8000-000000000001',true);
select set_config('request.jwt.claims','{"sub":"91000000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal1"}',true);
select throws_ok($$select public.academy_command('90000000-0000-4000-8000-000000000001','create_course',null,'{"titulo":"Outro Curso M23"}'::jsonb)$$,'42501','ACADEMY_CURATOR_REQUIRED','aluno sem academy.manage nao cria curso');

select set_config('request.jwt.claim.sub','91000000-0000-4000-8000-000000000002',true);
select set_config('request.jwt.claims','{"sub":"91000000-0000-4000-8000-000000000002","role":"authenticated","aal":"aal1"}',true);
insert into m23g0_module select public.academy_command('90000000-0000-4000-8000-000000000001','add_module',
 (select (r->>'id')::uuid from m23g0_course),'{"titulo":"Aula 1 - Introducao","tipo":"video","duracao_min":12}'::jsonb);
select is((select r->>'tipo' from m23g0_module),'video','curador adiciona modulo');

select throws_ok($$select public.academy_command('90000000-0000-4000-8000-000000000001','publish_course',(select (r->>'id')::uuid from m23g0_course),'{"status":"qualquer"}'::jsonb)$$,'22023','ACADEMY_STATUS_INVALID','status de publicacao invalido rejeitado');
select throws_ok($$select public.academy_command('90000000-0000-4000-8000-000000000001','enroll',(select (r->>'id')::uuid from m23g0_course),'{}'::jsonb)$$,'42501','ACADEMY_COURSE_NOT_AVAILABLE','matricula em curso nao publicado rejeitada');
select is((select (public.academy_command('90000000-0000-4000-8000-000000000001','publish_course',(select (r->>'id')::uuid from m23g0_course),'{"status":"publicado"}'::jsonb))->>'status'),'publicado','publicacao aceita apos conter modulo');

select set_config('request.jwt.claim.sub','91000000-0000-4000-8000-000000000001',true);
select set_config('request.jwt.claims','{"sub":"91000000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal1"}',true);
select is((select count(*) from public.academy_courses where tenant_id='90000000-0000-4000-8000-000000000001'),1::bigint,'aluno ve o curso do proprio tenant');

-- Escrita direta é negada por privilégio (sem DML para clientes).
do $$ declare hit boolean:=false; begin
 begin
  update public.academy_courses set titulo='nao deveria passar' where tenant_id='90000000-0000-4000-8000-000000000001';
 exception when insufficient_privilege then hit:=true;
 end;
 if not hit then raise exception 'M23_G0: authenticated escreveu em academy_courses'; end if;
end $$;
select ok(true,'authenticated nao escreve academy_courses diretamente');

select set_config('request.jwt.claim.sub','91000000-0000-4000-8000-000000000003',true);
select set_config('request.jwt.claims','{"sub":"91000000-0000-4000-8000-000000000003","role":"authenticated","aal":"aal1"}',true);
select is((select count(*) from public.academy_courses),0::bigint,'membro de outro tenant nao enxerga cursos');
select throws_ok($$select public.academy_command('90000000-0000-4000-8000-000000000002','create_course',null,'{"titulo":"Curso do Tenant B"}'::jsonb)$$,'42501','ACADEMY_ACCESS_DENIED','fail closed sem capacidade contratada');

-- Capacidade suspensa revoga a leitura mesmo para membro ativo.
set local role postgres;
update public.erp_tenant_capabilities set status='disabled' where tenant_id='90000000-0000-4000-8000-000000000001';
set local role authenticated;
select set_config('request.jwt.claim.sub','91000000-0000-4000-8000-000000000001',true);
select set_config('request.jwt.claims','{"sub":"91000000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal1"}',true);
select is((select count(*) from public.academy_courses where tenant_id='90000000-0000-4000-8000-000000000001'),0::bigint,'capacidade suspensa revoga a leitura');

set local role postgres;
update public.erp_tenant_capabilities set status='active' where tenant_id='90000000-0000-4000-8000-000000000001';
insert into public.erp_tenant_capability_exceptions (tenant_id,capability_key,effect,reason_hash,approval_ref,effective_from,expires_at,status)
 values ('90000000-0000-4000-8000-000000000001','academy.courses','deny',md5('m23g0')||md5('reason'),
  'approval:sha256:'||md5('m23g0')||md5('approval'),now()-interval '1 hour',now()+interval '1 day','active');
set local role authenticated;
select is((select count(*) from public.academy_courses where tenant_id='90000000-0000-4000-8000-000000000001'),0::bigint,'excecao deny bloqueia a academia');
set local role postgres;
delete from public.erp_tenant_capability_exceptions where tenant_id='90000000-0000-4000-8000-000000000001';
set local role authenticated;

select throws_ok($$select public.academy_command('90000000-0000-4000-8000-000000000001','complete_module',null,jsonb_build_object('module_id',(select r->>'id' from m23g0_module)))$$,'42501','ACADEMY_NOT_ENROLLED','concluir modulo sem matricula rejeitado');

select public.academy_command('90000000-0000-4000-8000-000000000001','enroll',(select (r->>'id')::uuid from m23g0_course),'{}'::jsonb);
select public.academy_command('90000000-0000-4000-8000-000000000001','complete_module',null,jsonb_build_object('module_id',(select r->>'id' from m23g0_module)));
select is((select progresso from public.academy_enrollments
  where tenant_id='90000000-0000-4000-8000-000000000001' and user_id='91000000-0000-4000-8000-000000000001'
  and course_id=(select (r->>'id')::uuid from m23g0_course)),100::numeric,'progresso alcanca 100 ao concluir o unico modulo');

select * from finish();
rollback;
