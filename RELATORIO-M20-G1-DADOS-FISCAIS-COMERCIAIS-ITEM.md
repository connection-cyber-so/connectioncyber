# M20-G1 — Migration 0037: dados fiscais e comerciais por item

Data: 07/09/2026

Executado sem interferência do usuário, a pedido dele, logo após o aceite das três decisões do
M20-G0 (ver `PARECER-TECNICO-M20-G0-CADASTROS-ESTRUTURAIS-SEGMENTOS.md`). Escopo desta gate:
somente a migration, preflight, rollback e pgTAP dos dados fiscais/comerciais por item — G2
(segmentos), G3 (telas) e G4 (seletor de estabelecimento) continuam pendentes, propositalmente
fora do escopo aqui.

## Entrega

- `supabase/migrations/0037_m20_item_fiscal_commercial_data.sql` — duas tabelas satélite de
  `erp_catalog_items`:
  - `erp_item_fiscal_data`: NCM, CEST, origem, CST/CSOSN + código, alíquotas de ICMS/IPI/FCP,
    CST PIS/COFINS, peso bruto/líquido, código ANP. CST/CSOSN aceitos espelham deliberadamente
    `packages/fiscal-contract/src/tax-profiles.mjs`.
  - `erp_item_commercial_data`: custo, margem, preço de venda sugerido, estoque mínimo, ponto de
    reposição, quantidade de reposição sugerida.
  - RLS própria por permissão nova `fiscal.item.read`/`fiscal.item.manage` (dado fiscal) e
    reaproveitando `catalog.read`/`catalog.manage` (dado comercial) — ver decisão de design
    abaixo.
- `supabase/preflight/0037_..._preflight.sql`, `supabase/rollback/0037_....rollback.sql`.
- `supabase/tests/0037_....test.sql` (20 asserções) + `.adversarial.test.sql` (12 asserções).
- `supabase/validation/build-0037-transaction.mjs` — gera a transação `begin;...rollback;`
  combinada, mesmo padrão de `build-0034-transaction.mjs`.

## Por que satélite, não coluna direta (decisão já tomada no G0)

Nem todo item emite nota (serviço/taxa/vale), o ciclo de vida fiscal muda independente do
cadastro do produto, e permite RLS mais restrita que o catálogo geral — replicando o padrão que
o schema já usa em `erp_party_documents`, `erp_item_identifiers`, etc.

## Bloqueio de ambiente encontrado e resolvido

Nenhum dos três caminhos previstos pra validar contra o Supabase de staging estava disponível
nesta sessão:
1. O conector Supabase MCP está ligado a outro projeto (`portal-teologico-os`), não ao
   `connectioncyber-staging` (`ozvylnaipubrmaadikvk`).
2. `.env.local` só tem a chave `anon` — sem `service_role` nem `DATABASE_URL`.
3. Docker não estava rodando no início da tarefa.

O usuário ligou o Docker Desktop (opção escolhida entre três oferecidas). Havia uma stack
Supabase local **já provisionada** (`supabase_db_connectioncyber`, imagem
`supabase/postgres:17.6.1.155`, porta 54322), parada em `0034` — dois passos atrás do staging
remoto (`0035`/`0036` não afetam esta gate, que só depende de objetos de M02/M05). Toda a
validação abaixo rodou ali. **Nenhum contato com o projeto Supabase remoto nesta gate.**

## Bugs reais encontrados pela validação e corrigidos antes de fechar o portão

1. **Overflow de precisão numérica.** `icms_rate`, `icms_base_percent`, `ipi_rate`, `fcp_rate`
   foram declarados `numeric(6,4)`. O default `icms_base_percent = 100` estourou a constraint —
   `100.0000` precisa de 7 dígitos de precisão (3 inteiros + 4 decimais), não 6. Corrigido para
   `numeric(7,4)` nas quatro colunas.
2. **Colisão de permissão com o M13.** A chave `fiscal.read` já existia desde a migration `0030`
   (M13 — fiscal de **documento**/NF-e: "Consulta documentos fiscais do tenant", usada em 7
   policies: `erp_tax_regimes_select`, `erp_fiscal_documents_select`, etc.). A 0037 ia registrar
   uma chave com o mesmo nome para um conceito diferente (classificação fiscal do **item**); como
   o insert usa `on conflict (key) do update`, isso teria **sobrescrito silenciosamente** a
   descrição de uma permissão em produção há mais de uma semana. Renomeado para
   `fiscal.item.read`/`fiscal.item.manage` em todos os 5 arquivos da gate. A permissão
   `fiscal.read` original foi restaurada com o texto exato da 0030 depois de ter sido apagada por
   engano durante a investigação deste achado (erro cometido e corrigido na mesma sessão).
3. **Dois erros de teste (não da migration).** `throws_ok(sql, código, texto)` do pgTAP foi
   escrito assumindo que o 3º argumento era descrição livre — na verdade é a **mensagem de erro
   exata esperada**, então 8 asserções falhavam por divergência de texto mesmo com o SQLSTATE
   certo. Corrigido para a forma de 2 argumentos `throws_ok(sql, código)`. Separadamente, a
   asserção do trigger de `updated_at` comparava `updated_at > created_at`, que nunca é
   verdadeiro dentro de uma única transação (`now()` fica congelado no início dela em Postgres) —
   trocada por uma checagem estrutural dos bits de `pg_trigger.tgtype` (ROW + BEFORE + UPDATE +
   função certa).

## Validação

- Dry-run completo (`begin; <migration> <pgtap> rollback;`) rodado direto no container Postgres
  local via `docker exec ... psql`, sem alterar volume: **32 de 32 pgTAP** (20 estrutural + 12
  adversarial — NCM inválido, CSOSN usado como CST, custo negativo, peso líquido > peso bruto,
  ponto de reposição abaixo do estoque mínimo, item de outro tenant rejeitado pela FK composta
  `(tenant_id,item_id)`, duplicidade `(tenant,item)`, `anon` sem privilégio de insert, cascade ao
  apagar o item). Confirmado zero resíduo após (`select ... where slug like 'm20-g1-synthetic%'`
  = 0 linhas, tabelas voltam a não existir).
- Como confirmação adicional (não exigida pelo escopo mínimo, mas de graça já que o banco é
  descartável): aplicação **real** da migration nesse mesmo banco local, seguida do **rollback
  real** com a variável de confirmação exigida — restaurou exatamente o estado anterior
  (`fiscal.read` intacto, histórico de migration parado em `0034`).
- Marcador: `M20_0037_TRANSACTION_32_OF_32_ROLLBACK`.

## O que NÃO foi feito nesta gate

- **Nenhuma aplicação em staging ou produção.** Falta credencial válida pro projeto certo (nem
  MCP Supabase nem `service_role`/`DATABASE_URL` local apontam pro `connectioncyber-staging`
  hoje) — aplicação persistente remota é um portão futuro (equivalente ao M20-G7 do parecer G0).
- M20-G2 (registro de segmentos), G3 (telas em abas) e G4 (seletor de estabelecimento) — fora do
  escopo pedido para esta gate.

## Próxima ação autorizável

Conectar a conta/projeto certo no MCP Supabase (ou fornecer `service_role`/`DATABASE_URL` do
staging) para eventualmente aplicar a `0037` de verdade em staging — ou seguir direto para
M20-G2/G3 localmente, que não dependem disso.
