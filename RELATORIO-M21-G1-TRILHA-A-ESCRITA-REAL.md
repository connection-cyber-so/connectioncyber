# M21-G1 (Trilha A) — habilitação real da escrita nos comandos do M20

Data: 07-08/09/2026

Autorizado pelo usuário: *"autorizo Trilha A + Trilha B pra execução autônoma agora"*, em
resposta ao `PARECER-TECNICO-ACESSO-REAL-CLIENTES-MANIA-CASA-BOLOS-MEI.md`. Este relatório
cobre a Trilha A (habilitar escrita real). A Trilha B (M05 real em `apps/portal`) é o próximo
gate, ainda não iniciado.

## O que travava antes deste gate

`packages/visual-persistence-supabase-adapter`: `persistentVisualWritesEnabled = false`
(hardcoded) e `selectVisualPersistence()` recusava incondicionalmente `mode:'persistent'`
com `PERSISTENT_WRITES_DISABLED`, mesmo com um transporte válido — provado por um teste que
checava que o dublê passado nem chegava a ser tocado. Além disso, **as 6 funções SQL dos
comandos novos do M20 (`erp_command_add_party_document_v1` etc.) nunca tinham sido criadas no
banco** — só existiam como nome de RPC no contrato (`COMMAND_BOUNDARIES`, M20-G3) e no
transporte síntetico (`local.ts`). Mesmo se a trava de cima fosse removida, chamar essas RPCs
falharia com "function does not exist".

## O que este gate entrega

### 1. Migration `0040_m21_g1_write_commands_m20.sql`

- Permissão nova `establishments.manage` (única tabela do M20 que nunca teve nenhuma via de
  escrita — `erp_establishments` só tinha SELECT desde o M16).
- Policy de UPDATE em `erp_establishments` (defesa em profundidade — a função abaixo não
  depende dela pra funcionar, roda como dona da tabela, mas nenhuma tabela do projeto deveria
  ficar sem nenhuma política de escrita registrada).
- `erp_command_receipts` e `erp_claim_command_v1` (envelope idempotente do M17) ampliados de
  7 para os 13 tipos de comando do contrato `M20-VISUAL-2.0`.
- **6 funções `SECURITY DEFINER` novas**, mesmo padrão exato do M17 (permissão+capacidade via
  `erp_require_command_access_v1`, claim/complete idempotente, `pg_advisory_xact_lock`,
  validação de payload dentro da função): `erp_command_add_party_document_v1`,
  `erp_command_add_party_contact_v1`, `erp_command_add_party_address_v1`,
  `erp_command_set_item_fiscal_data_v1` (upsert), `erp_command_set_item_commercial_data_v1`
  (upsert), `erp_command_set_establishment_vertical_v1`.
- Nomes de RPC batem exatamente com `COMMAND_BOUNDARIES` do M20-G3 — nada mudou no contrato,
  só passou a existir a função que faltava atrás do nome já contratado.
- **Decisão de escopo**: nenhuma permissão nova foi anexada a nenhum papel
  (`erp_role_permissions`) — só quem tem `is_platform_staff()=true` consegue executar estes
  comandos por enquanto, mesmo padrão já deixado em aberto pelo M20-G1 para
  `fiscal.item.manage`. Abrir para o próprio dono do tenant é trabalho da Trilha B.

### 2. `packages/visual-persistence-supabase-adapter`

`RPC_ALLOWLIST` de 7 para 13 (os 6 nomes acima adicionados) — sem isso a extensão do
selecionador (item 3) chamaria uma RPC bloqueada mesmo com a função já existindo no banco.

### 3. `apps/platform/src/features/persistence/selector.mjs` + `selected.ts`

- `selectVisualPersistence()` ganha um branch real para `mode:'persistent'` (parâmetro novo
  `persistentWritable`) — deixa de ser um `fail()` incondicional. Sem o transporte
  configurado, continua fail-closed (`PERSISTENT_WRITABLE_TRANSPORT_UNAVAILABLE`).
- `resolveVisualPersistenceMode()` aceita `'persistent'` como valor válido (além de
  `synthetic`/`persistent-read-only`). **O padrão do ambiente continua `synthetic`** —
  `.env.local.example` não muda o valor, só documenta a opção nova.
- `selected.ts`: novo `persistentWritableFacade` — mesmas leituras do modo somente leitura,
  só o `client` troca de `blockedClient` (recusa tudo) pro transporte real, que deriva tenant
  da sessão via `getCurrentTenantId()` (nunca de formulário) e usa a mesma sessão do usuário
  autenticado de sempre (sem chave de serviço).
- `visualPersistenceMode` (rótulo mostrado nas 6 telas que o exibem) deixa de ser um texto
  fixo que sempre dizia "comandos remotos bloqueados" mesmo em teoria com escrita ligada —
  agora reflete o modo de verdade resolvido. Novo `isWritePersistenceEnabled` exportado.
- `/cadastros`: a frase "Os registros desaparecem ao reiniciar o servidor" (que era fixa,
  independente do modo) agora só aparece fora do modo de escrita real.

### 4. Testes travados atualizados deliberadamente (mesmo padrão do bump de `CONTRACT_VERSION` no M20-G3)

Quatro invariantes de segurança que travavam em "7 comandos"/"escrita sempre recusada" foram
**reescritos, não relaxados** — cada um agora prova o caminho de sucesso E continua provando
que a falta do transporte certo ainda falha fechado:

- `packages/visual-persistence-supabase-adapter/tests/adapter.test.mjs`
- `packages/visual-persistence-supabase-adapter/tests/read-only-preflight.test.mjs`
- `apps/platform/tests/m18-g11-fail-closed-selection.test.mjs`
- `apps/platform/tests/m18-g12-persistent-read-only.test.mjs`

## Validação

- **Banco local** (`supabase_db_connectioncyber`, religado só pra este teste): 0035-0039
  aplicadas de verdade primeiro (nunca tinham sido persistentes nesse container). Dry-run
  `begin;...rollback;` da 0040: **59/59 pgTAP** (45 estrutural + 14 adversarial, incluindo
  dois testes reais de isolamento cross-tenant com `auth.uid()` simulado — um tenant não
  consegue gravar documento nem vertical usando id de outro). Aplicação real + rollback real
  testados no mesmo banco descartável, confirmando volta exata a 7 comandos / 0 permissões
  novas. Container parado de novo ao final.
- **JS/TS**: `npx tsc --noEmit` 0 erros; `node --test` — 193/193 em `apps/platform` (era 192),
  55/55 em `visual-persistence-supabase-adapter` (era 53, 2 testes novos), 52/52 em
  `visual-persistence-contract` (inalterado — já tinha 13 comandos desde o M20-G3); `eslint`
  0 avisos nos arquivos alterados.
- `next build` **não executado** — mesma cautela do M20-G6 (processos node ativos na
  máquina; já corrompeu `.next` duas vezes nesta sessão rodar build com dev server ao vivo).

## O que continua fora do seu alcance sem uma ação sua

1. **Migration 0040 não está em staging real** — só validada local. Mesmo passo a passo do
   CLI que você já executou pras 0037/0038/0039 (`supabase db push`).
2. **`SERVER_VISUAL_PERSISTENCE_MODE=persistent` não está setado em lugar nenhum real** — o
   padrão continua `synthetic` de propósito. Ativar de verdade em staging é variável de
   ambiente no Vercel do `apps/platform`, decisão sua, fora do meu alcance.
3. Mesmo depois dos dois passos acima, só **platform staff** consegue usar os 6 comandos
   novos (nenhuma permissão anexada a papel de tenant ainda) — o dono da Mania de Modas
   continua sem conseguir cadastrar nada sozinho até a Trilha B abrir uma tela pra ele.

## Próxima ação autorizável

Trilha B — abrir o M05 real em `apps/portal` (o app que o cliente loga), reaproveitando a
mesma camada de serviço/validação já construída no M20/M21-G1. Autorizada pelo usuário na
mesma mensagem desta Trilha A; ainda não iniciada.
