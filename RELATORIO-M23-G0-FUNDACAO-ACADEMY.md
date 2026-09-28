# M23 G0 — FUNDACAO ACADEMY — 0.1.0

Data: 27/09/2026. Ambientes: local (stack Supabase `supabase_db_connectioncyber`, PostgreSQL 17.6) e Supabase staging `ozvylnaipubrmaadikvk` (connectioncyber-staging). Produção não foi acessada nem alterada.

Decisão do usuário: núcleo único + 2 portas (fase 1 = `apps/portal` para clientes ERP existentes; fase 2 = `apps/site` B2C). G0 = fundação de dados do portal de ensino.

Autorização do usuário (27/09/2026): (1) validação transacional remota da 0044 com `ROLLBACK` e (2) aplicação persistente em staging. Ambas executadas.

## Entregas

- `supabase/migrations/0044_m23_academy_foundation.sql` (aditiva, transacional): capacidade `academy.courses`, permissões `academy.read`/`academy.manage`, tabelas `academy_courses`, `academy_modules`, `academy_enrollments`, `academy_progress`, `academy_events` (RLS + revoke total, somente `select` para `authenticated`), `erp_security.academy_capability/academy_access/academy_manage`, `public.academy_context`, comando único `public.academy_command` (create_course, update_course, publish_course, add_module, enroll, unenroll, complete_module) com advisory lock + rate limit 120/min + recálculo de progresso, e grants de `select` em `courses`/`products`/`cms_content` para `anon, authenticated` (correção do `42501` do catálogo público).
- `supabase/preflight/0044_..._preflight.sql`, `supabase/rollback/0044_...rollback.sql` (revoke de comandos, sem destruição), `supabase/verification/m23_g0_post_apply.sql`, `supabase/validation/build-0044-transaction.mjs`.
- `supabase/tests/0044_...test.sql` (18 estruturais) e `0044_...adversarial.test.sql` (14 adversariais).
- `apps/platform/tests/m23-g0-migration-0044-static.test.mjs` (14 testes estáticos).
- `supabase/validation/run-0044-remote.ps1` (runner remoto: fases `validate`, `apply`, `verify`, com log em `staging/logs/`).

## Evidências locais

1. Preflight local: `M23_G0_PREFLIGHT_OK` (objeto academy ausente, fundação 0016/0018 presente, 0044 não aplicada).
2. Transação gerada `supabase/validation/0044_transaction.generated.sql`: **32/32 pgTAP** em uma única transação com `ROLLBACK`, marcador `M23_G0_0044_TRANSACTION_32_OF_32_ROLLBACK`; preflight repetido logo depois volta a `M23_G0_PREFLIGHT_OK` (resíduo zero).
3. `supabase db push --local` reaplicou o laboratório (o lab estava em 0042; a 0043 e a 0044 entraram e o histórico local passou a 0044).
4. `m23_g0_post_apply.sql` local: 5 tabelas com RLS, 5 policies somente SELECT, `authenticated` sem DML, `anon` sem execução de `academy_command`, capability e permissões ativas, 4 funções presentes.
5. Suítes isoladas locais: **18/18** e **14/14** (linhas `ok N - ...` visíveis, `finish()` sem relato de falha).
6. `apps/platform` **214/214** naquele instante (hoje **237/237**, com os 23 testes estáticos das higienizações 0045/0046/0047), type-check limpo; parse SQL real (libpg_query) aprovado nos artefatos.

## Evidências remotas — fase `validate` (sem escrita persistente)

- Histórico remoto antes: `0001…0043` (0044 ausente).
- REST anônimo **antes**: `courses`, `products`, `cms_content` → HTTP 401 com `code "42501"` e hint `Grant the required privileges ... GRANT SELECT ON public.courses TO anon` — o bug que a 0044 corrige, confirmado no ambiente alvo.
- Preflight remoto: `M23_G0_PREFLIGHT_OK` antes e depois da transação.
- Transação remota: marcador `M23_G0_0044_TRANSACTION_32_OF_32_ROLLBACK`, `finish()` sem relato de falha (plano 18 + 14 executado integralmente).
- `count(*) from supabase_migrations.schema_migrations where version='0044'` = **0** ao final → nenhum objeto, permissão ou registro persistiu.

## Evidências remotas — fase `apply` (persistente, autorizada)

- `supabase db push --dry-run` selecionou **exclusivamente** `0044_m23_academy_foundation.sql` (nenhuma outra migration pendente).
- `supabase db push` aplicou a 0044.
- `m23_g0_post_apply.sql` remoto: 5 tabelas com RLS, 5 policies somente SELECT, `authenticated` sem DML, `anon` sem execução de comando, capability `academy.courses` ativa, permissões `academy.read`/`academy.manage` ativas, `academy_command`/`academy_context`/`academy_access`/`academy_manage` presentes.
- Testes estruturais remotos: plano **18** executado integralmente sem falha. Testes adversariais remotos: plano **14** idem.
- Preflight remoto passou a **recusar** (`M23_G0_PREFLIGHT: migration 0044 ja aplicada`) — prova de que a aplicação é observável.
- Histórico remoto final: `0001…0044`.
- REST anônimo **depois**: `courses`, `products`, `cms_content` → **HTTP 200** sem `42501`.

Logs: `staging/logs/m23-g0-remote-20260927-174458-validate.log`, `...-174845-apply.log`, `...-175334-verify.log`.

## Ajuste feito durante a validação remota

O seed dos fixtures dependia do trigger `on_auth_user_created` para materializar as linhas em `public.users`. No staging, `public.handle_new_user()` **diverge** do repositório: insere em `public.profiles` (drift pré-existente, não proveniente das migrations 0003/0018 do repositório). A primeira execução remota falhou com `23503` em `erp_tenant_memberships`. Correção aplicada somente no teste: `0044_m23_academy_foundation.adversarial.test.sql` insere explicitamente em `public.users` com `on conflict (id) do nothing` (idempotente nos dois ambientes — localmente insere 0 linhas, remoto insere 3). Pacote reconstruído e revalidado local e remotamente antes da aplicação.

A causa raiz foi corrigida logo em seguida (seção seguinte).

## Correção do drift — migration 0045 (aprovada pelo usuário em 27/09/2026)

`supabase/migrations/0045_handle_new_user_drift_fix.sql` (aditiva, transacional): reafirma a definição autoritativa da migration 0018 (`insert into public.users … on conflict (id) do nothing`, `security definer`, `search_path = ''`, sem fallback de tenant, `revoke` de `public, anon, authenticated`), garante o trigger `on_auth_user_created` (sem duplicar) e repara identidades órfãs (`auth.users` sem linha em `public.users`) com backfill idempotente e não destrutivo — a tabela `public.profiles` não é tocada.

Evidências remotas (`staging/logs/m23-hygiene-0045-remote-*.log`):

1. Preflight `M23_HYGIENE_0045_PREFLIGHT_OK`: `drift_present = true`, `orphans_pending = 1` (`connectioncyberso@gmail.com`), `signup_triggers = 1`.
2. Transação com `ROLLBACK`: marcador `M23_HYGIENE_0045_TRANSACTION_11_OF_11_ROLLBACK`; preflight repetido OK e drift ainda presente → resíduo zero.
3. `db push --dry-run` selecionou **somente** `0045_handle_new_user_drift_fix.sql`; `db push` aplicou (histórico `0001…0045`).
4. Pós-aplicação: suíte **11/11** (`finish()` sem relato de falha); `still_drift = false`, `writes_users = true`, `orphans_pending = 0`, `search_path=""`, `anon_can_execute = false`, `profiles_rows_preserved = 1`, `signup_triggers = 1`.
5. Preflight passou a **recusar** (`M23_HYGIENE_0045_PREFLIGHT: migration 0045 ja aplicada`).

Evidências locais: preflight OK → transação **11/11** com `ROLLBACK` e resíduo zero → `supabase db push --local` (histórico local `0001…0045`) → suíte **11/11** no estado aplicado → `still_drift = false` e `orphans = 0`. `apps/platform` **224/224**.

Artefatos: `supabase/preflight/0045_..._preflight.sql`, `supabase/rollback/0045_...rollback.sql` (contingência: restaura a definição legada — reabre o bug, só para emergência), `supabase/tests/0045_...test.sql` (11 asserções), `supabase/validation/build-0045-transaction.mjs` + `0045_transaction.generated.sql`, `apps/platform/tests/0045-handle-new-user-drift-fix-static.test.mjs` (10 testes estáticos).

Hashes SHA-256 (0045):

- `supabase/migrations/0045_handle_new_user_drift_fix.sql` — `3ED2612A66602BF94758AF0A05EB93C79FA5B8DFB59FD65BA0B081842C179383`
- `supabase/validation/0045_transaction.generated.sql` — `1304B8A04448C1F4D1712318AFC30F7AB5FB232043CBFDDF3C231E17E57EA902`
- `supabase/tests/0045_handle_new_user_drift_fix.test.sql` — `F4DB1BCA4ABB71F2B475010D76309C69842F783DB3C54EB081DC142B66E3803A`
- `supabase/preflight/0045_handle_new_user_drift_fix_preflight.sql` — `0DD71F65F1364DD70A0FCEB1017357D3C47B27274EB81F8C67FCCA9B97A3592C`
- `supabase/rollback/0045_handle_new_user_drift_fix.rollback.sql` — `37DF8A9EA6E81B9D8EA4AA333E5A1759A1D3077B983F3D2034E206F19A9B3270`

## Alinhamento de e-mail — migration 0046 (aprovada pelo usuário em 27/09/2026)

Causa da divergência: a identidade `61b57707-…` nasceu no cadastro de 01/09/2026 com
`joaquimmscoelho@gmail.com`; o e-mail foi trocado no Auth e confirmado em 02/09/2026
(`joaquimmscoelhoam@gmail.com`), mas **não há hook de UPDATE** — só o de INSERT da
0003/0018 — então `public.users.email` ficou defasado.

`supabase/migrations/0046_identity_email_alignment.sql` (aditiva, transacional): apenas
`UPDATE public.users` alinhando o e-mail ao valor vigente em `auth.users` (idempotente,
com guarda contra e-mail duplicado e preservando `nome`, `tenant_id` e demais colunas).

Evidências remotas (`staging/logs/m23-hygiene-0046-remote-20260927-183346-validate.log`):

1. Preflight `M23_HYGIENE_0046_PREFLIGHT_OK`: `target_in_auth = true`, `target_in_users = true`, `divergences = 1`.
2. Transação com `ROLLBACK`: `M23_HYGIENE_0046_TRANSACTION_4_OF_4_ROLLBACK`; preflight seguinte OK com `divergences = 1` → resíduo zero.
3. `db push --dry-run` escolheu **somente** a 0046; `db push` aplicou (histórico `0001…0046`).
4. Pós-aplicação: suíte **4/4**; `divergences = 0`, `users_email = auth_email = joaquimmscoelhoam@gmail.com`, `rows_with_email = 1`, `total_users = 12`.
5. Preflight passou a **recusar** (`M23_HYGIENE_0046_PREFLIGHT: migration 0046 ja aplicada`).

Evidências locais: preflight OK → transação **4/4** com `ROLLBACK` e resíduo zero → `supabase db push --local` (histórico local `0001…0046`) → suíte **4/4**. `apps/platform` **230/230**.

Hashes SHA-256 (0046):

- `supabase/migrations/0046_identity_email_alignment.sql` — `4DE252745E8673F22ACB27682380503C57F128DE8CA2CDF9CF62767C3C2AFCD3`
- `supabase/validation/0046_transaction.generated.sql` — `1F9456287C9827518EB69F6100C1C110E77D5FE84FBBD0908BD711622FBDF5C0`
- `supabase/tests/0046_identity_email_alignment.test.sql` — `42B63EF74F5531D2835192C047E408822019995AC718A59B83FC15FA86C5E311`
- `supabase/preflight/0046_identity_email_alignment_preflight.sql` — `39998AD911686A9F9DBE4D06918C17184597AE52AB7F319384CAEECC599B931A`
- `supabase/rollback/0046_identity_email_alignment.rollback.sql` — `6CBDED28B140C9EF4EB1E7BA05BE95585DF1AB7A7B0763C50113FD81A0E000AD`

## Sincronismo de e-mail — migration 0047 (aprovada pelo usuário em 27/09/2026)

`supabase/migrations/0047_sync_auth_email_trigger.sql` (aditiva, transacional): cria
`public.sync_auth_email()` (`security definer`, `search_path = ''`, `revoke` de
`public, anon, authenticated`) e o trigger `on_auth_user_email_changed`
(`after update of email on auth.users`, `when (old.email is distinct from new.email)`).
A função normaliza em minúsculas, atualiza `public.users.email` apenas quando houver
divergência e **recria a identidade** se ela estiver ausente (self-heal do drift da 0045);
e-mail nulo/vazio não altera nada. Se o e-mail novo já pertencer a outra identidade, a
troca no Auth falha por unicidade (comportamento desejado — impede duplicidade).

Evidências remotas (`staging/logs/m23-hygiene-0047-remote-20260927-213450-validate.log`):

1. Preflight `M23_HYGIENE_0047_PREFLIGHT_OK`: `function_present = false`, `trigger_present = false`, `divergences = 0`.
2. Transação com `ROLLBACK`: `M23_HYGIENE_0047_TRANSACTION_7_OF_7_ROLLBACK`; preflight seguinte OK com função/trigger ainda ausentes → resíduo zero.
3. `db push --dry-run` escolheu **somente** a 0047; `db push` aplicou (histórico `0001…0047`).
4. Pós-aplicação: suíte **7/7** (`signup` → troca de e-mail → identidade ausente → e-mail nulo); verificação `sync_triggers = 1`, `search_path=""`, `anon_can_execute = false`, `divergences = 0`, `total_users = 12`.
5. Preflight passou a **recusar** (`M23_HYGIENE_0047_PREFLIGHT: migration 0047 ja aplicada`).

Evidências locais: preflight → transação **7/7** com `ROLLBACK` e resíduo zero →
`supabase db push --local` (histórico local `0001…0047`) → suíte **7/7** no estado
aplicado. `apps/platform` **237/237** e type-check limpo.

Hashes SHA-256 (0047):

- `supabase/migrations/0047_sync_auth_email_trigger.sql` — `9821059A715D07F5D1F9A024EEB74B961E018B84B07F76D5C559326852EB8FB5`
- `supabase/validation/0047_transaction.generated.sql` — `85E3E82E0B0CB2109B98E3D52E4A948D48D0387DFA3116315EE13A31D763C849`
- `supabase/tests/0047_sync_auth_email_trigger.test.sql` — `452B2D28E4416A24560F821CC811290050E773693E2F7D2487816C8324CE6F8C`
- `supabase/preflight/0047_sync_auth_email_trigger_preflight.sql` — `3CA31445B01994073D5344A45C9E375773A853E95DCECCD2A74F9B3E9FC62864`
- `supabase/rollback/0047_sync_auth_email_trigger.rollback.sql` — `5969843E0F0F07D9D98322D6871D0A84052DFE6C236B47046C73D3F82B94D279`

## Hashes SHA-256

- `supabase/migrations/0044_m23_academy_foundation.sql` — `BA8B62C1B4380D0E765C31B8CBD4957CDD9366CC905C110C81AEE8C75E72C58E`
- `supabase/validation/0044_transaction.generated.sql` — `05CC13DD5A6A1169AC94484CCB06160E3A595570F3C330720CDA8F1F923F12C8`
- `supabase/validation/build-0044-transaction.mjs` — `E40DCAA5C774994440C864532D2E01620013668757D12220D8F76AE1103E0263`
- `supabase/tests/0044_m23_academy_foundation.test.sql` — `065548B3164BF33F7636885778EC285A40BB5A16AECD1A152BDFE76CCA6F3CA0`
- `supabase/tests/0044_m23_academy_foundation.adversarial.test.sql` — `C46ADFE082928329285139FBFC942172E1AF8256B105670457C7938E6E885A45`

## Cobertura dos testes adversariais

Criação e publicação de curso por curador; recusa para quem não tem `academy.manage`; módulo duplicado por ordem; status de publicação inválido; matrícula antes da publicação; RLS positivo (aluno vê 1 curso) e negativo (outro tenant vê 0); escrita direta negada por privilégio; fail-closed sem capacidade contratada; suspensão da capacidade; exceção `deny` ativa; conclusão de módulo sem matrícula; progresso recalculado até 100.

## Riscos residuais

- Drift do hook de signup **corrigido** (0045), e-mail da identidade **alinhado** (0046) e sincronismo contínuo **instalado** (0047).
- Se um usuário tentar trocar o e-mail no Auth para um endereço já usado por outra identidade, a troca falha por unicidade de `public.users.email` (impede duplicidade; decisão registrada).
- Contas existentes no staging: `connectioncyberso@gmail.com` (criada em Auth em 18/09/2026, confirmada no mesmo segundo, sem login posterior; sem tenant/membership — hoje só dependia do drift) e os sintéticos `*@connectioncyber.com.br` / `*.m22.staging@example.com`. `contatos@connectioncyber.com.br` é apenas o contato público do site, sem relação com Auth.
- Token de acesso `connectioncyber-cli-m23` (escopo Organization + Database read-write, expira em 7 dias) usado apenas para este gate; revogar quando dispensado.
- `academy.manage` em AAL1 (AAL2 pendente); sem cobrança/assinatura, mídia e trilhas (G1+); `/cursos` continua no legado `public.courses` até o G1.

## Não executado (exige aprovação específica)

- Alterações em produção.
