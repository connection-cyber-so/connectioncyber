begin;set local role postgres;create extension if not exists pgtap with schema extensions;set local search_path=public,extensions,pgtap;select plan(14);
select set_config('request.jwt.claim.role','service_role',true);

-- fundação: tenant sintético com 1 estabelecimento, provisionado pela função original do
-- M18 (0034) — exatamente como a Mania de Modas foi provisionada de verdade.
create temporary table m21g6_tenant as select public.erp_prepare_pilot_provisioning_v1('{"idempotencyKey":"pilot:staging:m21-g6-synthetic","slug":"m21-g6-synthetic","domain":"m21-g6-synthetic.connectioncyber.invalid","displayName":"Tenant Sintetico M21-G6","vertical":"retail","legalName":"TENANT SINTETICO SEM VALOR FISCAL","tradeName":"UNIDADE SINTETICA 1","cnpj":"44444444444444","stateRegistration":"ISENTO","establishmentCode":"HQ","ownerSubjectKey":"synthetic-owner-one","ownerEmailRef":"protected:M21_G6_SYNTHETIC_EMAIL_ONE","capabilities":["core.parties","core.catalog"]}'::jsonb)result;
select ok((select count(*)::integer from public.tenants where slug='m21-g6-synthetic')=1,'tenant sintético base existe');

-- adiciona um SEGUNDO estabelecimento (+ dono próprio) ao MESMO tenant — o caso real da
-- Loja da Benção (2 CNPJs, 2 donos, 1 tenant combinado).
create temporary table m21g6_result as select public.erp_prepare_pilot_establishment_v1('m21-g6-synthetic','{"idempotencyKey":"pilot:staging:m21-g6-synthetic-branch-2","establishmentCode":"UNIDADE2","establishmentKind":"branch","legalName":"TENANT SINTETICO SEM VALOR FISCAL","tradeName":"UNIDADE SINTETICA 2","cnpj":"55555555555555","stateRegistration":"ISENTO","verticalCode":"celular_multi_cnpj","ownerSubjectKey":"synthetic-owner-two","ownerEmailRef":"protected:M21_G6_SYNTHETIC_EMAIL_TWO"}'::jsonb)result from m21g6_tenant;
select ok(not(result->>'replayed')::boolean,'primeira adição de estabelecimento não é replay') from m21g6_result;
select is((select count(*)::integer from public.erp_establishments e join public.tenants t on t.id=e.tenant_id where t.slug='m21-g6-synthetic'),2,'tenant sintético agora tem 2 estabelecimentos');
select is((select count(*)::integer from public.erp_establishments e join public.tenants t on t.id=e.tenant_id where t.slug='m21-g6-synthetic' and e.cnpj='55555555555555' and e.vertical_code='celular_multi_cnpj' and e.state_registration='ISENTO' and e.kind='branch'),1,'segundo estabelecimento grava vertical/IE/tipo corretos');
select is((select count(*)::integer from public.erp_identity_provisioning_steps s join public.erp_identity_provisioning_runs r on r.id=s.run_id where r.idempotency_key='pilot:staging:m21-g6-synthetic-branch-2'),4,'quatro passos duráveis registrados para o segundo dono');
select is((select count(*)::integer from public.erp_auth_invitation_outbox o join public.erp_identity_provisioning_runs r on r.id=o.run_id where r.idempotency_key='pilot:staging:m21-g6-synthetic-branch-2' and o.status='pending'),1,'um convite pendente para o segundo dono');

-- replay idêntico não duplica nada
select ok((public.erp_prepare_pilot_establishment_v1('m21-g6-synthetic','{"idempotencyKey":"pilot:staging:m21-g6-synthetic-branch-2","establishmentCode":"UNIDADE2","establishmentKind":"branch","legalName":"TENANT SINTETICO SEM VALOR FISCAL","tradeName":"UNIDADE SINTETICA 2","cnpj":"55555555555555","stateRegistration":"ISENTO","verticalCode":"celular_multi_cnpj","ownerSubjectKey":"synthetic-owner-two","ownerEmailRef":"protected:M21_G6_SYNTHETIC_EMAIL_TWO"}'::jsonb)->>'replayed')::boolean,'replay idêntico é reconhecido');
select is((select count(*)::integer from public.erp_establishments e join public.tenants t on t.id=e.tenant_id where t.slug='m21-g6-synthetic'),2,'replay não duplica estabelecimento');

-- replay divergente (mesma chave, payload diferente) é rejeitado
select throws_ok($$select public.erp_prepare_pilot_establishment_v1('m21-g6-synthetic','{"idempotencyKey":"pilot:staging:m21-g6-synthetic-branch-2","establishmentCode":"UNIDADE3","establishmentKind":"branch","legalName":"OUTRO","tradeName":"OUTRO","cnpj":"66666666666666","stateRegistration":"ISENTO","verticalCode":"celular_multi_cnpj","ownerSubjectKey":"synthetic-owner-two","ownerEmailRef":"protected:M21_G6_SYNTHETIC_EMAIL_TWO"}'::jsonb)$$,'23505','idempotency conflict','replay divergente rejeitado');

-- CNPJ já usado (mesmo em outra chave de idempotência) é rejeitado — unicidade global
select throws_ok($$select public.erp_prepare_pilot_establishment_v1('m21-g6-synthetic','{"idempotencyKey":"pilot:staging:m21-g6-synthetic-branch-dup","establishmentCode":"UNIDADE4","establishmentKind":"branch","legalName":"OUTRO","tradeName":"OUTRO","cnpj":"55555555555555","stateRegistration":"ISENTO","verticalCode":"celular_multi_cnpj","ownerSubjectKey":"synthetic-owner-three","ownerEmailRef":"protected:M21_G6_SYNTHETIC_EMAIL_THREE"}'::jsonb)$$,'23505','pilot identity already exists','CNPJ duplicado rejeitado');

-- tenant inexistente é rejeitado
select throws_ok($$select public.erp_prepare_pilot_establishment_v1('m21-g6-tenant-inexistente','{"idempotencyKey":"pilot:staging:m21-g6-synthetic-branch-missing","establishmentCode":"UNIDADE5","establishmentKind":"branch","legalName":"OUTRO","tradeName":"OUTRO","cnpj":"77777777777777","stateRegistration":"ISENTO","verticalCode":"celular_multi_cnpj","ownerSubjectKey":"synthetic-owner-four","ownerEmailRef":"protected:M21_G6_SYNTHETIC_EMAIL_FOUR"}'::jsonb)$$,'55000','tenant not found','tenant inexistente rejeitado');

-- vertical desconhecida é rejeitada
select throws_ok($$select public.erp_prepare_pilot_establishment_v1('m21-g6-synthetic','{"idempotencyKey":"pilot:staging:m21-g6-synthetic-branch-badvertical","establishmentCode":"UNIDADE6","establishmentKind":"branch","legalName":"OUTRO","tradeName":"OUTRO","cnpj":"88888888888888","stateRegistration":"ISENTO","verticalCode":"vertical-que-nao-existe","ownerSubjectKey":"synthetic-owner-five","ownerEmailRef":"protected:M21_G6_SYNTHETIC_EMAIL_FIVE"}'::jsonb)$$,'55000','unknown vertical','vertical desconhecida rejeitada');

-- payload com chave protegida/segredo é rejeitado
select throws_ok($$select public.erp_prepare_pilot_establishment_v1('m21-g6-synthetic','{"idempotencyKey":"pilot:staging:m21-g6-synthetic-branch-secret","establishmentCode":"UNIDADE7","establishmentKind":"branch","legalName":"OUTRO","tradeName":"OUTRO","cnpj":"99999999999999","stateRegistration":"ISENTO","verticalCode":"celular_multi_cnpj","ownerSubjectKey":"synthetic-owner-six","ownerEmailRef":"protected:M21_G6_SYNTHETIC_EMAIL_SIX","password":"blocked"}'::jsonb)$$,'22023','unsafe establishment request','chave de segredo rejeitada');

-- chamador não-service_role é rejeitado
select set_config('request.jwt.claim.role','authenticated',true);
select throws_ok($$select public.erp_prepare_pilot_establishment_v1('m21-g6-synthetic','{}'::jsonb)$$,'42501','broker only','chamador authenticated rejeitado');
select set_config('request.jwt.claim.role','service_role',true);

select * from finish();
rollback;
