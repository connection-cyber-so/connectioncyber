begin;set local role postgres;create extension if not exists pgtap with schema extensions;set local search_path=public,extensions,pgtap;select plan(28);

-- Fixtures M25: compradores sinteticos, nunca dado real.
insert into auth.users (id,aud,role,email,encrypted_password,raw_app_meta_data,raw_user_meta_data,created_at,updated_at) values
 ('9b100000-0000-4000-8000-000000000001','authenticated','authenticated','m25-buyer1@example.invalid','',
  '{"provider":"email","providers":["email"]}'::jsonb,'{"nome":"M25 Buyer One"}'::jsonb,now(),now()),
 ('9b100000-0000-4000-8000-000000000002','authenticated','authenticated','m25-buyer2@example.invalid','',
  '{"provider":"email","providers":["email"]}'::jsonb,'{"nome":"M25 Buyer Two"}'::jsonb,now(),now());
-- public.users vem do hook handle_new_user (0045) em auth.users.

-- anon nao cria intencao.
select set_config('request.jwt.claims','{"role":"anon"}',true);
select throws_ok($$select public.saas_create_checkout_intent_v1('9b100000-0000-4000-8000-000000000001','padrao','{}'::jsonb)$$,
 '42501','broker only','anon nao chama create_intent');
select set_config('request.jwt.claims','{"role":"authenticated","sub":"9b100000-0000-4000-8000-000000000001"}',true);
select throws_ok($$select public.saas_create_checkout_intent_v1('9b100000-0000-4000-8000-000000000001','padrao','{}'::jsonb)$$,
 '42501','broker only','authenticated nao chama create_intent');

select set_config('request.jwt.claims','{"role":"service_role"}',true);
set local role service_role;

-- Allow-list fail-closed do payload.
select throws_ok($$select public.saas_create_checkout_intent_v1('9b100000-0000-4000-8000-000000000001','padrao',
  '{"slug":"m25x-loja","domain":"m25x.connectioncyber.com.br","displayName":"M25","vertical":"varejo",
    "legalName":"M25 LTDA","tradeName":"M25","cnpj":"12345678000199","establishmentCode":"MATRIZ",
    "password":"segredo"}'::jsonb)$$,'22023','invalid tenant payload','payload com senha rejeitado');
select throws_ok($$select public.saas_create_checkout_intent_v1('9b100000-0000-4000-8000-000000000001','padrao',
  '{"slug":"M25-BAD","domain":"m25x.connectioncyber.com.br","displayName":"M25","vertical":"varejo",
    "legalName":"M25 LTDA","tradeName":"M25","cnpj":"12345678000199","establishmentCode":"MATRIZ"}'::jsonb)$$,
 '22023','invalid tenant payload','slug malformado rejeitado');
select throws_ok($$select public.saas_create_checkout_intent_v1('9b100000-0000-4000-8000-000000000001','padrao',
  '{"slug":"m25x-loja","domain":"m25x.connectioncyber.com.br","displayName":"M25","vertical":"varejo",
    "legalName":"M25 LTDA","tradeName":"M25","cnpj":"1234","establishmentCode":"MATRIZ"}'::jsonb)$$,
 '22023','invalid tenant payload','cnpj curto rejeitado');
select throws_ok($$select public.saas_create_checkout_intent_v1('9b100000-0000-4000-8000-000000000001','inexistente',
  '{"slug":"m25x-loja","domain":"m25x.connectioncyber.com.br","displayName":"M25","vertical":"varejo",
    "legalName":"M25 LTDA","tradeName":"M25","cnpj":"12345678000199","stateRegistration":"12345678",
    "establishmentCode":"MATRIZ"}'::jsonb)$$,
 '22023','plan not available','plano inexistente rejeitado');

select ok((public.saas_create_checkout_intent_v1('9b100000-0000-4000-8000-000000000001','padrao',
  '{"slug":"m25-synthetic","domain":"m25-synthetic.connectioncyber.com.br","displayName":"M25 Loja Synthetic",
    "vertical":"varejo","legalName":"M25 Loja Synthetic ME","tradeName":"M25 Synthetic",
    "cnpj":"12345678000199","stateRegistration":"12345678","establishmentCode":"MATRIZ"}'::jsonb)->>'replayed')='false',
 'comprador criou a intencao');
select ok((select status='created'and request_hash~'^[a-f0-9]{64}$'and tenant_id is null
 from public.saas_checkout_intents where user_id='9b100000-0000-4000-8000-000000000001'),
 'intent criada em created com hash e sem tenant');
select ok((public.saas_create_checkout_intent_v1('9b100000-0000-4000-8000-000000000001','padrao',
  '{"slug":"m25-synthetic","domain":"m25-synthetic.connectioncyber.com.br","displayName":"M25 Loja Synthetic",
    "vertical":"varejo","legalName":"M25 Loja Synthetic ME","tradeName":"M25 Synthetic",
    "cnpj":"12345678000199","stateRegistration":"12345678","establishmentCode":"MATRIZ"}'::jsonb)->>'replayed')='true',
 'create_intent idempotente (replay da aberta)');
select public.saas_create_checkout_intent_v1('9b100000-0000-4000-8000-000000000001','padrao',
  '{"slug":"m25-synthetic","domain":"m25-synthetic.connectioncyber.com.br","displayName":"M25 Loja Synthetic Corrigida",
    "vertical":"varejo","legalName":"M25 Loja Synthetic ME","tradeName":"M25 Synthetic",
    "cnpj":"12345678000199","stateRegistration":"12345678","establishmentCode":"MATRIZ"}'::jsonb);
select ok((select tenant_payload->>'displayName'='M25 Loja Synthetic Corrigida'
 and request_hash ~ '^[a-f0-9]{64}$' from public.saas_checkout_intents
 where user_id='9b100000-0000-4000-8000-000000000001'),
 'replay com dados corrigidos atualiza payload e hash');
select throws_ok($$insert into public.saas_checkout_intents(user_id,plan_id,status,tenant_payload,request_hash)
 select '9b100000-0000-4000-8000-000000000001',id,'created','{}'::jsonb,'0000000000000000000000000000000000000000000000000000000000000000'
 from public.saas_plans where code='padrao'$$,'23505',null,'indice unico impede segunda intent aberta');

select throws_ok($$select public.saas_bind_preapproval_v1(
 (select id from public.saas_checkout_intents where user_id='9b100000-0000-4000-8000-000000000001'),'x','')$$,
 '22023','invalid preapproval id','bind com id invalido rejeitado');
select ok((public.saas_bind_preapproval_v1(
 (select id from public.saas_checkout_intents where user_id='9b100000-0000-4000-8000-000000000001'),
 'mp-pre-m25-0001','mp-cust-0001')->>'status')='sent','bind move a intent para sent');

select ok((public.saas_create_checkout_intent_v1('9b100000-0000-4000-8000-000000000002','padrao',
  '{"slug":"m25-second","domain":"m25-second.connectioncyber.com.br","displayName":"M25 Segunda",
    "vertical":"varejo","legalName":"M25 Segunda ME","tradeName":"M25 Segunda",
    "cnpj":"99888777000188","stateRegistration":"87654321","establishmentCode":"MATRIZ"}'::jsonb)->>'intentId') is not null,
 'segunda intent de outro comprador criada');
select throws_ok($$select public.saas_bind_preapproval_v1(
 (select id from public.saas_checkout_intents where user_id='9b100000-0000-4000-8000-000000000002'),
 'mp-pre-m25-0001','mp-cust-0002')$$,'23505','preapproval already bound','mesmo preapproval nao vincula a duas intents');
select throws_ok($$select public.saas_activate_intent_v1('mp-pre-m25-never',now()+interval '30 days')$$,
 '55000','intent not found','activate de preapproval desconhecido rejeitado');
select throws_ok($$select public.saas_activate_intent_v1('mp-pre-m25-0001',now()-interval '1 day')$$,
 '22023','invalid period','periodo vencido rejeitado');

select ok((public.saas_activate_intent_v1('mp-pre-m25-0001',now()+interval '30 days')->>'status')='active',
 'pagamento aprovado provisiona a assinatura como active');
select ok((select t.tenant_id is not null and t.provisioning_run_id is not null
 from public.saas_checkout_intents t
 where t.user_id='9b100000-0000-4000-8000-000000000001'),'intent provisionada com tenant e run');
select ok((select count(*) from public.erp_tenant_memberships m
 where m.user_id='9b100000-0000-4000-8000-000000000001'and m.status='invited')=1,
 'dono recebe membership invited do novo tenant');
select ok((select count(*) from public.erp_tenant_capabilities
 where tenant_id=(select tenant_id from public.saas_checkout_intents
                  where user_id='9b100000-0000-4000-8000-000000000001')
 and status='active')=13,'13 capabilities do plano ativas no tenant novo');
select ok((public.saas_activate_intent_v1('mp-pre-m25-0001',now()+interval '30 days')->>'replayed')='true',
 'activate idempotente no replay');

select throws_ok($$select public.saas_set_subscription_status_v1('mp-pre-m25-0001','unknown','x')$$,
 '22023','invalid status','status invalido rejeitado');
select public.saas_set_subscription_status_v1('mp-pre-m25-0001','cancelled','cliente cancelou');
select ok((select s.status='cancelled'and s.cancelled_at is not null
 and (select count(*) from public.erp_tenant_capabilities c
      where c.tenant_id=s.tenant_id and c.status='suspended')=13
 from public.saas_subscriptions s where s.mp_preapproval_id='mp-pre-m25-0001'),
 'cancelamento marca cancelled e suspende as capabilities');
select ok((public.saas_set_subscription_status_v1('mp-pre-m25-0001','cancelled','cliente cancelou')
  ->>'replayed')='true','cancelamento idempotente no replay');

select ok(public.saas_record_billing_event_v1('preapproval','mp-pre-m25-0001','mp-pre-m25-0001',null,
  'authorized','{"id":"mp-pre-m25-0001"}'::jsonb)is not null,'evento de billing gravado');
select ok(public.saas_record_billing_event_v1('preapproval','mp-pre-m25-0001','mp-pre-m25-0001',null,
  'authorized','{"id":"mp-pre-m25-0001"}'::jsonb)is null,'evento repetido e ignorado (idempotente)');
select throws_ok($$select public.saas_record_billing_event_v1('preapproval','mp-evt-bad',null,null,'authorized','[]'::jsonb)$$,
 '22023','invalid billing event','payload nao-objeto rejeitado');

select * from finish();
rollback;
