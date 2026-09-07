# M20-G4 — Seletor de estabelecimento (individual/todas as lojas)

Data: 07/09/2026

Executado sem interferência do usuário, a pedido dele, junto com o M20-G3 na mesma sessão
(compartilha o bump de contrato `M20-VISUAL-2.0` documentado no `RELATORIO-M20-G3-TELAS-EM-ABAS.md`).

## Decisão de escopo — dois caminhos diferentes, não um só

A auditoria do M20-G0 apontou "nenhuma tela usa `establishment_id`" como lacuna única, mas ao
desenhar esta gate ficou claro que **duas arquiteturas diferentes** coexistem no
`apps/platform`:

- `/vendas` e `/servicos` **já leem Supabase real direto** (`createClient()` +
  `requireCurrentTenantId()`), sem passar pelo transporte visual do M18. `erp_sales`,
  `erp_quotes`, `erp_service_orders` e `erp_appointments` já têm `establishment_id` na tabela
  real — filtrar por loja aqui é mudança direta e real, sem depender de nada síntetico.
- `/operacoes` (estoque) e `/catalogo` passam pelo transporte visual sintético (mesmo do G3), que
  nunca teve estoque fragmentado por loja — é um único saldo consolidado desde o M18-G5.

Por isso o seletor foi implementado de dois jeitos coerentes com cada realidade, não um
compromisso único que fingiria funcionar igual nos dois.

## Mecanismo comum

- `lib/establishment-scope.ts`: cookie `cc-establishment-scope` guarda só uma **preferência de
  exibição** (qual loja olhar), nunca autoriza nada sozinho — toda leitura que usa esse valor
  ainda filtra por `tenant_id` primeiro. `null`/`'all'` = "todas as lojas".
- `components/EstablishmentSwitcher.tsx`: `<select>` + botão, formulário 100% servidor (mesmo
  padrão do M19-G4, sem JS de cliente) — trocar de loja é uma navegação normal.
- `features/establishments/actions.ts`: `setEstablishmentScopeAction` (grava o cookie, relê as
  quatro páginas) + `setEstablishmentVerticalAction` (usa o comando `establishment.vertical.set`
  do M20-G3 pra ligar uma vertical do M20-G2 a um estabelecimento específico).

## `/vendas` e `/servicos` — filtragem real

`listQuotes`, `listSales`, `listServiceOrders` e `listAppointments` ganharam um parâmetro
`establishmentId` opcional — sem ele, comportamento idêntico ao de antes (nenhuma regressão);
com ele, adiciona `.eq('establishment_id', establishmentId)` na mesma query Supabase que já
existia. `listAssets` **não** ganhou o filtro — `erp_assets` não tem coluna `establishment_id`
no schema real (ativo pertence à pessoa, não à loja), então adicionar o filtro ali seria inventar
uma coluna que não existe.

Nova leitura real `features/establishments/service.ts::listEstablishments` alimenta o seletor
nessas duas telas com as lojas de verdade do tenant.

## `/operacoes` e `/catalogo` — seletor real, saldo ainda consolidado

O seletor funciona (lê `erp_establishments` sintético via o mesmo transporte do G3, grava a
mesma preferência) e a página **documenta explicitamente** que o saldo mostrado continua
consolidado de todas as lojas — fragmentar `state.stock` por estabelecimento no transporte
sintético exigiria reescrever a lógica de venda/recebimento de estoque que **7 testes
existentes conferem por trecho exato de código-fonte** (`state.stock[draft.itemId]-=...`, etc.).
Refatorar isso de raiz só para a tela de demonstração — sem que nenhum dado seja real de
qualquer forma hoje — não trazia benefício proporcional ao risco de quebrar cobertura já
madura. Registrado como próximo passo quando a fragmentação por loja for decidida com dado real.

Em compensação, `/catalogo` usa a loja selecionada (ou a primeira, se nenhuma) pra decidir **qual
vertical mostrar na aba Atributos** (M20-G3) — union real entre G2 (vertical), G3 (aba) e G4
(seletor), funcionando de ponta a ponta mesmo com o estoque ainda consolidado.

`/operacoes` também ganhou `EstablishmentVerticalForm` — formulário que liga uma vertical (M20-G2)
a um estabelecimento específico, usando o comando `establishment.vertical.set` do M20-G3.

## Validação

Mesma rodada do G3 (arquivos compartilhados): `tsc --noEmit` limpo, `next lint` limpo, `next
build` com sucesso, `node --test tests/*.test.mjs` **179/179** sem regressão — incluindo
asserções específicas de G4 (`tests/m20-g3-g4-tabs-establishment.test.mjs`): seletor presente
nas quatro telas, filtro por `establishmentId` em vendas/serviços sem quebrar a leitura sem
filtro, escopo de estabelecimento nunca chama Supabase direto, página de estoque documenta o
limite do saldo consolidado.

## O que NÃO foi feito nesta gate

- Estoque por loja de verdade (fragmentação de `state.stock`) — decisão registrada acima, não
  esquecimento.
- `listAssets` não filtra por estabelecimento (schema real não tem essa coluna).
- Nenhuma migration nova — G4 reaproveita `erp_establishments.vertical_code` já criado no M20-G2
  e o comando `establishment.vertical.set` já criado no M20-G3.
