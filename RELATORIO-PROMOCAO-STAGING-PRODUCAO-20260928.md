# Relatório — Promoção staging → produção (28/09/2026)

Estado: **CONCLUÍDO**. Escopo autorizado pelo usuário em 28/09/2026 ("Promover
staging→produção": merge `staging`→`main`, deploy do portal e alinhamento do
Supabase de produção).

## 1. Achado que motivou o portão

A regra `STATUS` §4.2 manda "Vercel Production apontar exclusivamente para o
Supabase de produção", mas as três envs do `connectioncyber-portal` apontavam
para o **staging** `ozvylnaipubrmaadikvk` (exceção registrada em 28/09, linha da
promoção manual do deploy). O Supabase de produção `qfggetvashdxyuvlhihq` estava
parado na migration `0013` (38 tabelas, 11 tenants/3 usuários fixtures de
15-16/08, 0 cursos) enquanto staging chegou a `0049`.

## 2. Inventário prévio

- Produção: histórico `0001–0013`; `public.profiles` **inexistente** (única
  divergência de inventário: 223 vs 224 tabelas `public`); schema `auth`/`storage`
  idêntico ao staging (0 divergências de coluna); site Vercel `connectioncyber`
  já apontava para `qfg` (só o portal estava fora da regra).
- `main` estava 235 commits atrás de `staging` (869 arquivos).
- Storage do staging: 0 objetos (nenhum binário a migrar).

## 3. Execução

1. **Backups locais** (antes de qualquer escrita) em
   `%TEMP%\connectioncyber-backups\`:
   - `producao-qfg-antes-promocao.sql` (schema, 56 KB, SHA-256 `1BFABD90257CD551…`)
   - `producao-qfg-data-antes.sql` (dados, 57 KB)
   - `staging-schema.sql` (855 KB) + `staging-data.sql` (232 KB, SHA-256 registrado
     no histórico da sessão) — 50 tabelas com dados.
2. **Schema**: `supabase db push --project-ref qfggetvashdxyuvlhihq` aplicou
   **exatamente as 36 migrations `0014`→`0049`** (dry-run antes confirmou a
   lista; `seeds=[]`, `roles=[]`). Histórico final: **49/49, última `0049`**.
3. **`public.profiles`**: criada na produção exatamente como no dump do staging
   (PK, FK → `auth.users` ON DELETE CASCADE, RLS habilitado sem policy,
   grants `anon`/`authenticated`/`service_role`).
4. **Dados**: `TRUNCATE` das 50 tabelas-alvo (`… cascade`, sem `restart identity`
   — a conexão não é dona das sequences de `auth`) seguido do restore integral
   de `staging-data.sql` (INSERTs + `setval` final) via `supabase db query --linked`.
5. **Verificação por comparação** staging × produção — idênticas nas 10 contagens
   de referência: `auth_users=12, tenants=5, memberships=10, caps=20, dominios=1,
   cursos=1, vinculos=5, modulos=21, estabs=4, matriculas=1`. Conferido que a
   produção antiga só tinha dados em 11 tabelas, todas cobertas pelo dump do
   staging → **zero dado descartável perdido** (só fixtures antigas).
6. **Env do portal**: `NEXT_PUBLIC_SUPABASE_URL` → `https://qfggetvashdxyuvlhihq.supabase.co`
   e `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` → anon key do `qfg`
   (payload `{ref:qfg…, role:anon, exp:2102126657}`; `--type config` exigido pela
   CLI nova para prefixo `NEXT_PUBLIC_`). `PORTAL_CENTRAL_HOSTS` mantida.
7. **REST anônimo da produção**: `courses`/`products`/`cms_content` = **200**.
8. **PR #1** `staging`→`main` com todos os checks verdes (Quality gates +
   critical-contracts + previews Vercel dos 2 projetos) → merge **`130fc38`**.
9. **Deploys automáticos de produção** disparados pelo merge nos dois projetos:
   portal `connectioncyber-portal-ki72z9pmm` **Ready/Production** (build ~1 min) e
   site `connectioncyber` (primeiro deploy de produção em 42 dias).

## 4. Smoke pós-promoção

| URL | Resultado |
|---|---|
| `https://portal.connectioncyber.com.br/login` | 200 |
| `https://portal.connectioncyber.com.br/` | 307 → login |
| `https://portal.connectioncyber.com.br/academia` | 307 → login |
| `https://portal.connectioncyber.com.br/treinamento` | 307 → login |
| `https://connectioncyber.com.br/` | 200 |
| REST anon `qfg` (`courses`/`products`/`cms_content`) | 200 |

## 5. Riscos e pendências residuais

- **Login real** depende de teste do usuário (12 identidades migradas com hashes
  e MFA preservados; senhas não são conhecidas por nós).
- **R-003** parcialmente mitigado: dumps completos dos dois projetos em
  `%TEMP%\connectioncyber-backups\` e a restauração foi exercitada com sucesso
  de fato (produção), mas continua sem backup gerenciado com RPO/RTO definidos.
- O restore deixou `session_replication_role`/sequences alinhados via `setval` do
  próprio dump; sequences de tabelas fora dos 50 alvos mantiveram o valor antigo.
- Deploy do site publicou 42 dias de mudanças acumuladas de uma vez (comportamento
  esperado da promoção).
- Staging permanece em `ozvylnaipubrmaadikvk` (0049) como ambiente de
  desenvolvimento — Preview continua apontando para ele.

## 6. Comandos-chave (reexecução/rollback)

- Backup: `supabase db dump --project-ref <ref> --file <arquivo>` (+ `--data-only`).
- Schema: `supabase db push --project-ref qfggetvashdxyuvlhihq --yes` (já aplicado).
- Rollback de dados: restaurar `producao-qfg-{schema,data}-antes.sql` pelo mesmo
  fluxo (truncate + `db query -f`), lembrando de remover `public.profiles` criada.
- Envs: `vercel env add <nome> production --type config --value <valor> --yes`.
