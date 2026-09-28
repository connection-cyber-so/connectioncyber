-- M23-G1.1 — seed do primeiro curso do portal (staging ozvylnaipubrmaadikvk, 27/09/2026)
-- Conteúdo: "Mini Curso: Atalhos de Teclado – Windows e Office"
-- (F:\Projetos\connectioncyber-documentacao\minicursos\Mini Curso Atalhos de Teclado – Windows e Office.md)
-- Escrita 100% via public.academy_command (0044), na sessão do owner de cada tenant.
-- Idempotente: pula o tenant em que o curso já existe.

do $$
declare
  v_tenant uuid := 'ef7d3cbc-f50c-4306-9b1b-3b5be75c3a5c'; -- Loja da Benção
  v_uid uuid := 'd4472f6b-8b6e-4d1a-af0b-4a6f71c6d0ca';     -- satcyber001 (owner)
  v_title text := 'Atalhos de Teclado — Windows e Office';
  v_course uuid;
begin
  perform set_config('request.jwt.claims', json_build_object('sub', v_uid, 'role', 'authenticated', 'aal', 'aal1')::text, true);
  if exists (select 1 from public.academy_courses where tenant_id = v_tenant and titulo = v_title) then
    raise notice 'seed: curso ja existe em %', v_tenant; return;
  end if;
  v_course := (public.academy_command(v_tenant, 'create_course', null, jsonb_build_object(
    'titulo', v_title,
    'descricao', 'Mini curso com cerca de 90 atalhos em 7 módulos e 2 horas: fundamentos, atalhos universais, Windows, Word, Excel, PowerPoint e Teams — com exercícios guiados sem mouse, desafios de fixação, avaliação final de 10 perguntas e plano de 7 dias. Cada módulo tem tabela de atalhos, exercício e desafio.',
    'categoria', 'Produtividade', 'idioma', 'pt-BR', 'nivel', 'iniciante')) ->> 'id')::uuid;
  perform public.academy_command(v_tenant, 'add_module', v_course, jsonb_build_object('titulo','Módulo 0 — Fundamentos e a pegadinha PT x EN','tipo','texto','ordem','0','duracao_min','10','conteudo_ref','academy:atalhos/modulo-0'));
  perform public.academy_command(v_tenant, 'add_module', v_course, jsonb_build_object('titulo','Módulo 1 — Atalhos universais','tipo','texto','ordem','1','duracao_min','15','conteudo_ref','academy:atalhos/modulo-1'));
  perform public.academy_command(v_tenant, 'add_module', v_course, jsonb_build_object('titulo','Módulo 2 — Windows: janelas e áreas de trabalho','tipo','texto','ordem','2','duracao_min','20','conteudo_ref','academy:atalhos/modulo-2'));
  perform public.academy_command(v_tenant, 'add_module', v_course, jsonb_build_object('titulo','Módulo 3 — Windows: arquivos, capturas e sistema','tipo','texto','ordem','3','duracao_min','15','conteudo_ref','academy:atalhos/modulo-3'));
  perform public.academy_command(v_tenant, 'add_module', v_course, jsonb_build_object('titulo','Módulo 4 — Word','tipo','texto','ordem','4','duracao_min','20','conteudo_ref','academy:atalhos/modulo-4'));
  perform public.academy_command(v_tenant, 'add_module', v_course, jsonb_build_object('titulo','Módulo 5 — Excel','tipo','texto','ordem','5','duracao_min','25','conteudo_ref','academy:atalhos/modulo-5'));
  perform public.academy_command(v_tenant, 'add_module', v_course, jsonb_build_object('titulo','Módulo 6 — PowerPoint e Teams','tipo','texto','ordem','6','duracao_min','10','conteudo_ref','academy:atalhos/modulo-6'));
  perform public.academy_command(v_tenant, 'add_module', v_course, jsonb_build_object('titulo','Encerramento — avaliação final e plano de 7 dias','tipo','quiz','ordem','7','duracao_min','5','conteudo_ref','academy:atalhos/encerramento'));
  perform public.academy_command(v_tenant, 'publish_course', v_course, jsonb_build_object('status','publicado'));
  raise notice 'seed: curso % criado em %', v_course, v_tenant;
end$$;

do $$
declare
  v_tenant uuid := 'a673859e-18f9-4c01-84aa-4b6d92774874'; -- Casa de Bolos Aconchego
  v_uid uuid := '1caa7cd9-b848-4a63-803e-d14b82613cf0';     -- casadebolocc (owner)
  v_title text := 'Atalhos de Teclado — Windows e Office';
  v_course uuid;
begin
  perform set_config('request.jwt.claims', json_build_object('sub', v_uid, 'role', 'authenticated', 'aal', 'aal1')::text, true);
  if exists (select 1 from public.academy_courses where tenant_id = v_tenant and titulo = v_title) then
    raise notice 'seed: curso ja existe em %', v_tenant; return;
  end if;
  v_course := (public.academy_command(v_tenant, 'create_course', null, jsonb_build_object(
    'titulo', v_title,
    'descricao', 'Mini curso com cerca de 90 atalhos em 7 módulos e 2 horas: fundamentos, atalhos universais, Windows, Word, Excel, PowerPoint e Teams — com exercícios guiados sem mouse, desafios de fixação, avaliação final de 10 perguntas e plano de 7 dias. Cada módulo tem tabela de atalhos, exercício e desafio.',
    'categoria', 'Produtividade', 'idioma', 'pt-BR', 'nivel', 'iniciante')) ->> 'id')::uuid;
  perform public.academy_command(v_tenant, 'add_module', v_course, jsonb_build_object('titulo','Módulo 0 — Fundamentos e a pegadinha PT x EN','tipo','texto','ordem','0','duracao_min','10','conteudo_ref','academy:atalhos/modulo-0'));
  perform public.academy_command(v_tenant, 'add_module', v_course, jsonb_build_object('titulo','Módulo 1 — Atalhos universais','tipo','texto','ordem','1','duracao_min','15','conteudo_ref','academy:atalhos/modulo-1'));
  perform public.academy_command(v_tenant, 'add_module', v_course, jsonb_build_object('titulo','Módulo 2 — Windows: janelas e áreas de trabalho','tipo','texto','ordem','2','duracao_min','20','conteudo_ref','academy:atalhos/modulo-2'));
  perform public.academy_command(v_tenant, 'add_module', v_course, jsonb_build_object('titulo','Módulo 3 — Windows: arquivos, capturas e sistema','tipo','texto','ordem','3','duracao_min','15','conteudo_ref','academy:atalhos/modulo-3'));
  perform public.academy_command(v_tenant, 'add_module', v_course, jsonb_build_object('titulo','Módulo 4 — Word','tipo','texto','ordem','4','duracao_min','20','conteudo_ref','academy:atalhos/modulo-4'));
  perform public.academy_command(v_tenant, 'add_module', v_course, jsonb_build_object('titulo','Módulo 5 — Excel','tipo','texto','ordem','5','duracao_min','25','conteudo_ref','academy:atalhos/modulo-5'));
  perform public.academy_command(v_tenant, 'add_module', v_course, jsonb_build_object('titulo','Módulo 6 — PowerPoint e Teams','tipo','texto','ordem','6','duracao_min','10','conteudo_ref','academy:atalhos/modulo-6'));
  perform public.academy_command(v_tenant, 'add_module', v_course, jsonb_build_object('titulo','Encerramento — avaliação final e plano de 7 dias','tipo','quiz','ordem','7','duracao_min','5','conteudo_ref','academy:atalhos/encerramento'));
  perform public.academy_command(v_tenant, 'publish_course', v_course, jsonb_build_object('status','publicado'));
  raise notice 'seed: curso % criado em %', v_course, v_tenant;
end$$;

do $$
declare
  v_tenant uuid := '7f2f05c7-94a0-42dc-bcfc-7b3105c391e3'; -- Mania de Modas
  v_uid uuid := '72d1f5ee-0e6b-4551-bba2-dff88a7766e1';     -- maniademodacc (owner)
  v_title text := 'Atalhos de Teclado — Windows e Office';
  v_course uuid;
begin
  perform set_config('request.jwt.claims', json_build_object('sub', v_uid, 'role', 'authenticated', 'aal', 'aal1')::text, true);
  if exists (select 1 from public.academy_courses where tenant_id = v_tenant and titulo = v_title) then
    raise notice 'seed: curso ja existe em %', v_tenant; return;
  end if;
  v_course := (public.academy_command(v_tenant, 'create_course', null, jsonb_build_object(
    'titulo', v_title,
    'descricao', 'Mini curso com cerca de 90 atalhos em 7 módulos e 2 horas: fundamentos, atalhos universais, Windows, Word, Excel, PowerPoint e Teams — com exercícios guiados sem mouse, desafios de fixação, avaliação final de 10 perguntas e plano de 7 dias. Cada módulo tem tabela de atalhos, exercício e desafio.',
    'categoria', 'Produtividade', 'idioma', 'pt-BR', 'nivel', 'iniciante')) ->> 'id')::uuid;
  perform public.academy_command(v_tenant, 'add_module', v_course, jsonb_build_object('titulo','Módulo 0 — Fundamentos e a pegadinha PT x EN','tipo','texto','ordem','0','duracao_min','10','conteudo_ref','academy:atalhos/modulo-0'));
  perform public.academy_command(v_tenant, 'add_module', v_course, jsonb_build_object('titulo','Módulo 1 — Atalhos universais','tipo','texto','ordem','1','duracao_min','15','conteudo_ref','academy:atalhos/modulo-1'));
  perform public.academy_command(v_tenant, 'add_module', v_course, jsonb_build_object('titulo','Módulo 2 — Windows: janelas e áreas de trabalho','tipo','texto','ordem','2','duracao_min','20','conteudo_ref','academy:atalhos/modulo-2'));
  perform public.academy_command(v_tenant, 'add_module', v_course, jsonb_build_object('titulo','Módulo 3 — Windows: arquivos, capturas e sistema','tipo','texto','ordem','3','duracao_min','15','conteudo_ref','academy:atalhos/modulo-3'));
  perform public.academy_command(v_tenant, 'add_module', v_course, jsonb_build_object('titulo','Módulo 4 — Word','tipo','texto','ordem','4','duracao_min','20','conteudo_ref','academy:atalhos/modulo-4'));
  perform public.academy_command(v_tenant, 'add_module', v_course, jsonb_build_object('titulo','Módulo 5 — Excel','tipo','texto','ordem','5','duracao_min','25','conteudo_ref','academy:atalhos/modulo-5'));
  perform public.academy_command(v_tenant, 'add_module', v_course, jsonb_build_object('titulo','Módulo 6 — PowerPoint e Teams','tipo','texto','ordem','6','duracao_min','10','conteudo_ref','academy:atalhos/modulo-6'));
  perform public.academy_command(v_tenant, 'add_module', v_course, jsonb_build_object('titulo','Encerramento — avaliação final e plano de 7 dias','tipo','quiz','ordem','7','duracao_min','5','conteudo_ref','academy:atalhos/encerramento'));
  perform public.academy_command(v_tenant, 'publish_course', v_course, jsonb_build_object('status','publicado'));
  raise notice 'seed: curso % criado em %', v_course, v_tenant;
end$$;
