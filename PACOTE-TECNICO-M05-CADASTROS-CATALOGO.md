# Pacote técnico M05 — Cadastros e catálogo universal

## Objetivo

Entregar um núcleo multiempresa único para pessoas, colaboradores, unidades, produtos, serviços, peças, ingredientes, variações, atributos e composições, sem forks por cliente.

## Escopo implementado

- 16 tabelas `erp_*`, todas vinculadas a `tenant_id` e protegidas por RLS;
- pessoas físicas/jurídicas com papéis, documentos, contatos, endereços e vínculo de empregado;
- catálogo com nove tipos de item, unidades e conversões, variações, identificadores e atributos;
- composições para kits, receitas e listas de materiais;
- permissões `parties.read`, `parties.manage`, `catalog.read` e `catalog.manage`;
- criação atômica de pessoa por RPC `erp_create_party`, com tenant derivado da sessão no servidor;
- telas `/cadastros` e `/catalogo` no painel da plataforma;
- migration 0021, preflight somente leitura, rollback de laboratório e 44 asserções pgTAP.

## Segurança e isolamento

- nenhuma tabela concede acesso ao papel `anon`;
- `authenticated` recebe grants mínimos, sempre filtrados por RLS;
- operações exigem membership/permissão do tenant ou papel de equipe da plataforma;
- não há política de exclusão física para usuários autenticados;
- chaves estrangeiras compostas impedem referências cruzadas entre tenants;
- valor de atributo deve pertencer ao mesmo atributo selecionado;
- nenhuma conta, fixture ou dado real integra o pacote.

## Validação local

- `npm test`: 9/9 testes existentes aprovados;
- `npm run type-check`: aprovado;
- `npx eslint src --no-cache`: aprovado;
- `git diff --check`: aprovado;
- Supabase dry-run: somente `0021_m05_parties_catalog.sql` pendente;
- build completo já havia sido aprovado antes do ajuste final; nova execução foi impedida por cache `.next` em uso por processo Node existente. TypeScript e ESLint do código final foram aprovados.

## Estado remoto

A migration 0021 não foi aplicada. O próximo portão exige autorização explícita para executar preflight, aplicar exclusivamente a 0021 no Supabase de staging e rodar os 44 testes remotos. Produção, Vercel, DNS, contas e dados reais permanecem intocados.

## Rollback

O rollback fornecido destina-se exclusivamente a laboratório vazio. Depois de uso real, qualquer correção deve ser aditiva/forward-fix para preservar dados e auditoria.
