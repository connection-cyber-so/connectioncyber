# M20-G5 — Preparação para a reforma tributária (IBS/CBS) no cadastro de item

Data: 07/09/2026

Executado a pedido do usuário, a partir de pergunta direta ("o que já dá pra implementar da
reforma tributária?"). Escopo deliberadamente pequeno: dois campos novos, opcionais, aditivos —
não muda nenhum comportamento fiscal existente (CSOSN/CST/ICMS do M20-G1 continuam intactos e
obrigatórios como já eram).

## Fonte — schema oficial, não estimativa

Em vez de responder de memória sobre a reforma (risco real de informação desatualizada em tema
regulatório), a resposta foi extraída direto do pacote XSD oficial da SEFAZ **já fixado e
hash-verificado neste projeto**:
`packages/fiscal-contract/schemas/nfe/010e_v1.02/xsd/PL_010e_v1.02/NFe/DFeTiposBasicos_v1.00.xsd`
(pacote `010e_v1.02`, publicado pela SEFAZ em 10/07/2026, baixado em 28/08/2026 — ver
`schema-manifest.json` do pacote). Esse XSD já contém o "Grupo de informações dos tributos IBS,
CBS e Imposto Seletivo" (`TTribNFCe`/`TTribNFe`), com dois campos identificadores simples:

- **`CST`** (tipo `TCST`) — Código de Situação Tributária do IBS/CBS, **3 dígitos**, paralelo e
  distinto do CST/CSOSN do ICMS que já existe em `erp_item_fiscal_data.tax_code`.
- **`cClassTrib`** (tipo `TcClassTrib`) — Código de Classificação Tributária do IBS/CBS,
  **6 dígitos**.

## O que ficou de fora, de propósito

- **Alíquotas/valores** (`pIBSUF`, `pIBSMun`, `pCBS`, `vIBS`, `vCBS`) — 2026 é fase de teste com
  alíquotas simbólicas ainda em calibração; não há valor estável pra gravar hoje.
- **Grupo de Imposto Seletivo** (`CSTIS`, `cClassTribIS`, `pIS`) — relevante só pra produtos
  específicos (bebidas alcoólicas, cigarros — bate com a vertical "Adega" do M20-G2), fica pra um
  portão futuro se/quando esse cliente entrar.
- **A tabela oficial de significado de cada código de 6 dígitos do `cClassTrib`** — é anexo
  separado da LC 214/2025, não vem no XSD estrutural. Mesma regra que já vale pra NCM/CSOSN hoje
  (ver M13): aguarda confirmação do contador antes de preencher de verdade.

## Entrega

- `supabase/migrations/0039_m20_item_fiscal_reforma_tributaria.sql`: duas colunas novas em
  `erp_item_fiscal_data`, **ambas nullable** — `cst_ibs_cbs` (`check ~ '^[0-9]{3}$'`) e
  `cclass_trib` (`check ~ '^[0-9]{6}$'`). Nenhuma RLS/permissão nova (a tabela já tem RLS própria
  do M20-G1).
- `supabase/preflight/0039_..._preflight.sql`, `supabase/rollback/0039_....rollback.sql`.
- `supabase/tests/0039_....test.sql` (6 asserções) + `.adversarial.test.sql` (4 asserções).
- `supabase/validation/build-0039-transaction.mjs`.
- Mockup (`cadastros-tela-unica.html`, aba Fiscal do produto): seção "Reforma tributária
  (IBS/CBS)" com selo "novo · opcional em 2026", campos CST IBS/CBS e cClassTrib com máscara de
  dígitos.

## Validação

- Banco local (`supabase_db_connectioncyber`) estava parado desde a limpeza de memória pedida
  pelo usuário — religado só pra este teste. Como 0037/0038 nunca tinham sido aplicadas de forma
  persistente nele (só dry-run), apliquei as duas de verdade primeiro pra poder testar a 0039 em
  cima.
- Dry-run `begin;...rollback;`: **10 de 10 pgTAP** (6 estrutural + 4 adversarial — formato
  errado com letra, com quantidade de dígito errada, nos dois campos). Zero resíduo confirmado.
- Aplicação real + rollback real testados no mesmo banco descartável.
- **Limpeza final**: revertidas 0039, 0038 e 0037 nessa ordem, devolvendo o banco local
  exatamente ao estado anterior (`0034`, `fiscal.read` intacto) — e o container Docker parado de
  novo ao final, mantendo a memória liberada como o usuário pediu.
- **Não aplicado em staging nem produção** — mesma limitação de credencial dos gates anteriores.

## Próxima ação autorizável

Nenhuma — os dois campos ficam disponíveis (nullable) pra quando o contador confirmar os
primeiros códigos reais. Se/quando isso acontecer, a atualização é só popular os valores, sem
migration nova.
