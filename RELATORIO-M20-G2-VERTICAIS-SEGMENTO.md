# M20-G2 — Verticais de segmento + atributos exigidos por item

Data: 07/09/2026

Executado sem interferência do usuário, a pedido dele. Escopo: catálogo global de verticais de
negócio + template de atributos extras exigidos por vertical, ligando cada item ao ramo de
negócio do estabelecimento. G3 (telas em abas) e G4 (seletor de estabelecimento) continuam
pendentes.

## Correção de auditoria — achada só ao desenhar esta gate

O `PARECER-TECNICO-M20-G0-CADASTROS-ESTRUTURAIS-SEGMENTOS.md` original (G0) **não tinha visto**
que `public.erp_segment_profiles` / `erp_segment_profile_capabilities` /
`erp_tenant_segment_profiles` já existem desde a migration `0016` (fundação M16) — 5 perfis
largos (`retail_general`, `apparel_stationery`, `workshop`, `food_service`,
`professional_services`) já mapeados para recomendação de módulos/capacidades por segmento.

Isto **não tornou esta gate redundante**, mas mudou o desenho: `erp_segment_profiles` resolve
"quais módulos um segmento típico usa" (eixo já pronto); o que faltava, e esta gate resolve, é o
eixo mais fino de "quais campos extras um item deste ramo de negócio precisa" (ex.: validade pra
casa de bolos, teor alcoólico pra adega) — um problema diferente, que os 5 perfis largos são
grossos demais para responder (ex.: `apparel_stationery` cobre moda + papelaria + variedades +
calçados junto, mas cada um precisa de campos de item diferentes). O parecer G0 foi corrigido
com uma nota apontando este achado.

## Entrega

- `supabase/migrations/0038_m20_business_verticals.sql`:
  - `erp_business_verticals` (catálogo global, `code` como chave primária, `segment_profile_key`
    como FK opcional para `erp_segment_profiles` — herda a recomendação de módulos de lá).
  - `erp_vertical_attribute_requirements` (template de atributo — `attribute_code`/
    `attribute_name`/`data_type`/`required`, **sem** FK direta pra `erp_attributes` porque
    `erp_attributes` é por-tenant e uma vertical é conceito global; materializar de fato essas
    linhas no `erp_attributes` de um tenant que adota a vertical fica para um portão futuro de
    provisionamento).
  - `erp_establishments.vertical_code`, coluna nova (nullable, FK pra `erp_business_verticals`)
    — vertical fica no estabelecimento, não no tenant, pra não colidir com o `tenants.vertical`
    texto livre já usado pelo fluxo de provisionamento do M18 (`erp_prepare_pilot_provisioning_v1`
    recebe `vertical` como parâmetro) e porque é onde as outras especificidades operacionais já
    vivem (`erp_fiscal_series`, `erp_stock_movements`, etc.).
  - Seed: as 14 verticais confirmadas na seção 6 do parecer G0, cada uma ligada a um dos 5
    perfis de segmento existentes, mais 13 requisitos de atributo reais (não placeholder) —
    ex.: `casa_de_bolos` exige `validade_dias` (number, obrigatório), `adega` exige
    `teor_alcoolico` (number, obrigatório) + `volume_ml` (number, opcional), `loja_calcados`
    exige `numeracao` (option, obrigatório).
- `supabase/preflight/0038_..._preflight.sql`, `supabase/rollback/0038_....rollback.sql`.
- `supabase/tests/0038_....test.sql` (20 asserções) + `.adversarial.test.sql` (9 asserções).
- `supabase/validation/build-0038-transaction.mjs`.

## RLS

Mesmo padrão de `erp_segment_profiles`/`erp_permissions`: catálogo global, `select` livre pra
qualquer `authenticated`, **nenhuma policy de insert/update** — só `service_role`/migration
altera o catálogo. `erp_establishments.vertical_code` é escrito através da política de update já
existente da tabela `erp_establishments` (nenhuma RLS nova necessária pra uma coluna aditiva).

## Erro de contagem próprio, pego pela primeira rodada de validação

Planejei `select plan(21)` no teste estrutural mas escrevi 20 instruções (a checagem de RLS conta
como 2 testes numa única instrução, contabilizei errado). O dry-run acusou
`"planned 30 tests but ran 29"` de cara — corrigido para `plan(20)` + `plan(9)` = 29 no total.
Nenhum bug de schema desta vez (diferente do M20-G1, que pegou dois bugs reais).

## Validação

- Dry-run `begin;...rollback;` direto no container Postgres local (mesmo ambiente do G1,
  `supabase_db_connectioncyber`, parado em `0034`, sem contato com staging remoto): **29 de 29
  pgTAP** (20 estrutural + 9 adversarial — código de vertical inválido, `data_type` inválido,
  duplicidade de atributo, atributo referenciando vertical inexistente, vertical referenciando
  perfil de segmento inexistente, estabelecimento referenciando vertical inexistente, `anon` sem
  privilégio de insert nos dois catálogos, vertical duplicada). Zero resíduo confirmado depois.
- Aplicação real + rollback real testados no mesmo banco descartável: 14 verticais + 13
  requisitos inseridos na aplicação; rollback restaurou exatamente o estado anterior
  (`0034`, colunas/tabelas removidas).
- Marcador: `M20_0038_TRANSACTION_29_OF_29_ROLLBACK`.

## O que NÃO foi feito nesta gate

- Nenhuma aplicação em staging ou produção — mesma limitação de credencial do G1.
- Materialização das linhas de `erp_vertical_attribute_requirements` em `erp_attributes` real de
  um tenant quando ele adota uma vertical — fica para um portão de provisionamento futuro.
- G3 (telas em abas) e G4 (seletor de estabelecimento) — fora do escopo desta gate.

## Próxima ação autorizável

G3 (reescrever os formulários de cadastro de pessoa/produto em abas, cobrindo os campos fiscais
do G1 e puxando os atributos exigidos pela vertical do G2) ou resolver primeiro a credencial de
staging para promover 0037+0038 de verdade.
