# M21-G2 (Trilha B, primeira fatia) — cadastro real de pessoas em apps/portal

Data: 08/09/2026

Continuação da autorização *"autorizo Trilha A + Trilha B pra execução autônoma agora"*.
Trilha A (M21-G1) fechou a escrita real no backend. Este gate é a primeira fatia real da
Trilha B: abrir uma tela de cadastro de verdade no app que o **cliente** loga
(`apps/portal`), não mais só a equipe ConnectionCyber (`apps/platform`).

## Por que só "primeira fatia"

O pedido original cobria Cliente + Produto + Empresa. Este gate entrega só **Cliente/
Fornecedor (pessoas)** — Catálogo (produto) e edição de dados da própria empresa ficam para
o próximo gate. Motivo: cada tela nova em `apps/portal` precisa da própria checagem de
tenant via `loadPortalAccess()` (diferente do `apps/platform`, que deriva tenant de
`public.users.tenant_id`) — melhor fechar uma fatia completa e testada do que duas fatias
pela metade.

## Achado que precisou de correção antes da tela funcionar de verdade

`erp_prepare_pilot_provisioning_v1` (M18, migration 0034) já concede **todas as permissões
ativas** ao papel `owner` no momento em que um tenant é provisionado — então Casa de Bolos e
o MEI (Aldo/Eliane), quando forem provisionados, já nascem com `parties.manage` etc.
liberado, sem trabalho extra. O problema era só a **Mania de Modas**, provisionada no
M18-G21 (04/09), **antes** de `fiscal.item.manage` (M20-G1) e `establishments.manage`
(M21-G1) existirem — o papel `owner` dela nunca recebeu essas duas.

- **Migration `0041_m21_g2_backfill_owner_permissions.sql`**: um `insert...select...on
  conflict do nothing` genérico (não hardcoded pras duas permissões de hoje) que
  reconcilia qualquer papel `owner` contra o catálogo atual de permissões ativas — fecha a
  lacuna da Mania de Modas hoje e de qualquer tenant futuro que fique pra trás do mesmo
  jeito.
- Validado: dry-run **9/9 pgTAP** (4 estrutural + 5 adversarial: prova que fecha a lacuna,
  não toca papel não-owner, é idempotente, nunca concede permissão inativa). Aplicação real
  + rollback real testados no Docker local (efeito zero ali — banco local não tem a Mania
  de Modas de verdade; o efeito real só existe em staging).

## A tela em si

- `apps/portal/src/domain/br-documents.ts`: mesma validação de CPF/CNPJ (dígito mod-11) do
  `apps/platform/src/domain/br-documents.mjs` — duplicado de propósito (apps são
  independentes, ver `CLAUDE.md`), não importado entre apps. 10 testes próprios.
- `apps/portal/src/features/persistence/writable.ts`: diferente de `apps/platform`, aqui
  **não existe** modo síntetico/somente-leitura — é a primeira tela real do portal, vai
  direto pro transporte que grava de verdade (`createVisualPersistenceClient` +
  `createSupabasePersistenceTransport`, os mesmos pacotes do M18/M21-G1). Tenant só sai de
  uma `loadPortalAccess()` com `kind:'authorized'` — nunca de formulário.
- `apps/portal/src/app/(portal)/cadastros/page.tsx`: lista pessoas já cadastradas
  (`client.read('parties')`) + formulário de cadastro, mesmo idioma visual das telas já
  existentes do portal (`.content-heading`, `.form-stack`, `.alert`) — sem framework de
  formulário novo, sem JS de cliente.
- `apps/portal/src/app/(portal)/cadastros/nova-pessoa/route.ts`: `POST` — mesmo idioma
  exato de `auth/set-branding/route.ts` (same-origin check, `loadPortalAccess()`,
  redirect 303 com `?erro=`/`?sucesso=1`) — só que a escrita passa pelo comando idempotente
  real (`client.execute('party.create', ...)`, que chama
  `erp_command_create_party_v1` por trás), não uma RPC simples.
- `(portal)/layout.tsx`: "Cadastros" deixa de ser `<span class="nav-item pending">` e vira
  link real.
- 7 testes novos (`m21-g2-cadastros-portal.test.ts`), mesmo rigor do M19-G4 (branding):
  same-origin, tenant nunca de formulário, sem `service_role`, escrita só pelo comando do
  contrato (nunca insert direto na tabela).

## Validação

- `npx tsc --noEmit --incremental false`: 0 erros.
- `npx tsx --test tests/*.test.ts`: **105/105** (88 pré-existentes + 10 de br-documents +
  7 de M21-G2).
- `npx eslint` nos arquivos novos/alterados: 0 avisos.
- `next build` não executado (mesma cautela dos gates anteriores nesta sessão).

## O que ainda falta pra fechar a Trilha B por completo

1. Catálogo (cadastro de produto) — mesmo padrão desta fatia, próximo gate.
2. Edição dos dados da própria empresa (`erp_establishments`) pelo cliente — hoje só
   leitura existe no portal; escrita continua exclusiva de migration/staff.
3. Aplicar `0041` em staging real (mesmo passo a passo do CLI já usado pras anteriores) —
   sem isso, o papel `owner` da Mania de Modas real continua sem `fiscal.item.manage`/
   `establishments.manage`, mesmo com a tela pronta.
4. Ativar `SERVER_VISUAL_PERSISTENCE_MODE`/deploy do `apps/portal` em staging real — a
   tela existe no código, mas só funciona de verdade depois do deploy.

## Próxima ação autorizável

Fechar a Trilha B com Catálogo (produto) no `apps/portal`, replicando o mesmo padrão desta
fatia — ou, se preferir, priorizar aplicar `0040`/`0041` em staging real primeiro e validar
esta tela com a Mania de Modas de verdade antes de construir mais telas.
