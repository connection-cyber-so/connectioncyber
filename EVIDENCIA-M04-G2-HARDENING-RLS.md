# M04-G2 — evidência de staging e hardening RLS

Data: 26/08/2026
Ambiente: Supabase staging `ozvylnaipubrmaadikvk`
Produção: não alterada

## Resultado da migration 0018

- Preflight remoto: `M04_PREFLIGHT_OK`.
- Histórico remoto: migrations `0001` a `0018` sincronizadas.
- Identidades Auth antes/depois: 3/3.
- Profiles antes/depois: 3/3.
- Memberships, roles e ledgers criados: 0.
- Helpers `current_aal()` e `has_permission_at_aal(...)`: presentes.
- Nenhuma conta, convite, membership, role ou fator MFA foi criado.

## Gates de aplicação

- Plataforma: 9/9 testes Node, type-check, lint e build aprovados.
- Site: 5/5 testes Node, type-check, lint e build aprovados.
- Dependências: 0 vulnerabilidades reportadas por `npm install`.
- Migration 0018: aplicada exclusivamente em staging após autorização explícita.

## Achado posterior

O advisor oficial do Supabase identificou 16 tabelas legadas no schema `public`
sem RLS. O problema é anterior à migration 0018 e impede declarar o banco pronto
para dados de clientes.

A migration `0019_harden_legacy_public_rls.sql` foi preparada com:

- RLS obrigatório nas 16 tabelas;
- deny-by-default para estruturas internas;
- leitura pública somente de cursos, produtos e CMS publicados/ativos;
- analytics e mídia limitados à identidade autenticada;
- preflight somente leitura;
- rollback com confirmação explícita;
- 21 testes pgTAP.

## Aplicação remota da 0019

- Autorização específica recebida em 26/08/2026.
- Primeira aplicação recusada porque a política de produtos referenciava `ativo`; a
  transação reverteu integralmente e não registrou a migration.
- Schema real confirmado: a coluna correta é `products.status`.
- Migration corrigida, preflight e dry-run repetidos; aplicação concluída.
- Resultado: 16/16 tabelas protegidas, zero `rls_disabled_in_public`, seis políticas
  mínimas presentes e contagens de identidades/dados inalteradas.

## Próximo hardening

A `0020_harden_legacy_functions.sql` foi preparada para definir `search_path` vazio em
`set_updated_at()` e remover acesso anônimo de `is_platform_staff()`. Os acessos
autenticados do painel e a resolução pública de hostname do portal são intencionais.

## Aplicação remota da 0020

- Autorização específica recebida em 26/08/2026.
- Preflight `M0020_PREFLIGHT_OK`; dry-run selecionou exclusivamente a 0020.
- Migration aplicada; histórico local/remoto sincronizado de `0001` a `0020`.
- `set_updated_at()` usa `search_path=""`.
- `anon` não executa `is_platform_staff()`; `authenticated` e `service_role` preservados.
- Advisor: zero RLS desabilitado, zero `search_path` mutável e zero execução anônima de
  `is_platform_staff()`.
- Contagens preservadas: 3 identidades, 3 profiles, zero memberships, roles ou ledgers.

## Portão manual restante

Acesso ao Dashboard confirmado via GitHub em 26/08/2026. O controle “Prevent use of
leaked passwords” está disponível somente no plano Supabase Pro ou superior; a organização
staging usa o plano Free. Nenhum upgrade ou compra foi realizado.

O aviso fica aceito exclusivamente no staging gratuito. Antes do piloto/produção, o projeto
deverá usar plano compatível ou implementar controle compensatório aprovado. Os outros
quatro avisos de funções `SECURITY DEFINER` correspondem a RPCs intencionais do
portal/painel e permanecem documentados e cobertos por testes de autorização.

O acesso à Vercel também foi confirmado via GitHub: projeto
`connectioncyberso/connectioncyber`, produção `Ready`, domínio
`connectioncyber.com.br`. Nenhuma configuração ou deployment foi alterado.
