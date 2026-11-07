-- Teste 0061 (leitura, sem dados fictícios novos)
-- Sem auth.uid() deve retornar false, mesmo para o tenant da Nuvem.
begin;
select set_config('request.jwt.claims', '', true);
select public.storefront_has_permission('00000000-0000-0000-0000-000000000001'::uuid, 'parties.read') as sem_sessao_deve_ser_false;
rollback;
