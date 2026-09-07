# M20-G0 — Cadastros estruturais universais + verticais de segmento

Data: 07/09/2026

Escopo desta etapa: auditoria do sistema legado (SICNET) e do estado atual do `apps/platform`,
comparação campo a campo, identificação de lacunas e definição da sequência de portões para
fechar a estrutura de cadastro **antes** de retomar a migração de qualquer cliente real (Mania
de Modas incluída). Nenhum código, migration ou dado alterado nesta etapa — só leitura e análise.

Fontes analisadas:
- Telas do sistema legado instalado nesta máquina (menus + cadastro de pessoa PF/PJ + cadastro
  de produto + configuração de NFC-e), extraídas de
  `C:\Users\joaqu\Downloads\DadosConnectionCyber\menssagens\` — sistema identificado como
  **SICNET** (nome visível no menu "Internet → Site da SICNET").
- Duas empresas reais capturadas nas telas de exemplo: **Stillus Perfumaria** (Bazar Parceiras
  Mix LTDA) e **Depósito Nascimento** — usadas aqui só como referência de quais campos um
  cadastro de verdade carrega, não como dado a replicar.
- Código-fonte de `apps/platform`: `src/features/parties/*`, `src/features/catalog/*`,
  `supabase/migrations/0016`, `0021` (M05), `0022` (M06), `0025` (M09), `0026` (M10),
  `packages/fiscal-contract/src/tax-profiles.mjs`, `packages/capability-contract/src`.

## Achado de segurança — não relacionado ao código, ação sua

A tela `NFCeConfInformacao.png` expõe em texto puro o **CSC (Código de Segurança do
Contribuinte)** de uma NFC-e em produção, dentro de um print salvo em `Downloads/`. CSC é
credencial de assinatura fiscal — quem tiver esse valor pode forjar a chave de acesso de notas
daquela empresa. Recomendação: mover essa pasta de prints para um local que não sincronize/backup
automático não controlado, e se possível rotacionar o CSC na SEFAZ/emissor. Isto não bloqueia o
resto deste parecer, é uma ação independente sua.

## 1. O que a auditoria confirma que já existe (não precisa reconstruir)

| Necessidade que você descreveu | Onde já está resolvida | Estado |
|---|---|---|
| Cadastro de empresa é padrão, muda o regime tributário | `erp_establishments` (migration 0016) + `TAX_PROFILES` (`fiscal-contract/tax-profiles.mjs`: NORMAL_RPA, SIMPLE_NATIONAL, SIMPLE_EXCESS, MEI) | Schema pronto, testado |
| Um cliente com **2 CNPJs** (celular: venda+reparo) precisando de visão individual E global | Um `tenant` → N `erp_establishments`, cada um com seu próprio CNPJ; estoque/vendas/OS já têm `establishment_id`; catálogo e cadastro de pessoas são compartilhados no nível do tenant (visão global automática) | Schema pronto — **falta só a tela** com o seletor "esta loja / todas as lojas" |
| Segmento oficina (CFTV/elétrica/solar também se encaixam aqui) | M09 `erp_service_orders`, `erp_assets`, `erp_vehicles`, `erp_appointments`, orçamento→aprovação→execução→garantia | Construído e testado (68/68), sem dado real |
| Segmento restaurante | M10 `erp_food_tabs`, `erp_dining_tables`, `erp_kitchen_tickets`, `erp_modifiers`, ficha técnica/rendimento (`erp_recipe_yields`) | Construído e testado (72/72), sem dado real |
| Produto com receita/composição (Casa de Bolos: fabrica e vende) | `erp_item_compositions` + `erp_item_composition_lines` (BOM/receita/kit), `erp_stock_lots.manufactured_at`/`expires_at` (data de fabricação e validade por lote) | Schema pronto, sem tela |
| Campos que só existem para certos segmentos (óleo de motor vs. óleo de fritura) | `erp_attributes` + `erp_attribute_values` + `erp_item_attribute_values` — EAV genérico já implementado, com tipos option/text/number/boolean | Schema pronto, **sem conceito de "segmento" para acionar automaticamente o grupo certo de atributos** |
| Código de barras + código interno | `erp_item_identifiers` (`type in gtin/ean13/ean8/internal/sku/supplier`) | Schema pronto |

Isto muda o diagnóstico: **a fundação não está fraca — está sem acabamento.** M05/M06/M09/M10
já passaram por gate com pgTAP (44 a 96 asserções cada, todas verdes em staging). O que falta é
justamente o que você sentiu na pele: layout de tela pronto e alguns campos que nunca foram
desenhados porque nenhum gate pediu eles ainda.

## 2. Lacunas reais (confirmadas linha a linha contra os prints do legado)

| # | Lacuna | Evidência | Bloqueia o quê |
|---|---|---|---|
| L1 | `erp_catalog_items` não tem **nenhum campo fiscal** (NCM, CEST, origem, CST/CSOSN, alíquota ICMS, base de cálculo, IPI, CST PIS/COFINS, peso bruto/líquido) | Comparado com `3padrao-cadastroproduto-dados fiscais.png` e `-outros.png`; migrations 0021/0022 não têm essas colunas; `tax-profiles.mjs` só valida regime do tenant, não carrega por item | **Emissão de NF-e para qualquer produto**, de qualquer cliente — é impeditivo total, não só da Mania de Modas |
| L2 | Nenhum campo de **custo, margem, preço de venda padrão, estoque mínimo, sugestão de compra** no item — só existe preço via `erp_price_lists` (tabela de preço avulsa, não "preço padrão do item") | Comparado com `padrao-cadastroproduto.png` (Preço de custo / Margem de lucro / Preço de venda / Quantidade mínima) | Cadastro de produto usável no dia a dia; reposição de estoque |
| L3 | Formulários da UI são esqueleto de aceite de gate, não tela de cadastro | `PartyForm.tsx` (4 campos: tipo, papel, nome, CPF/CNPJ) e `CatalogForms.tsx` (código, nome, tipo, unidade) — nenhum dos dois toca endereço, contato, documento, dados fiscais, preço | É exatamente o "não descobri como deixar os layouts prontos" que você relatou |
| L4 | Não existe conceito de **segmento de negócio** (varejo de moda, oficina, restaurante, papelaria, material de construção, revenda) que ligue automaticamente um tenant/estabelecimento ao grupo de atributos extras dele | Nenhuma tabela/coluna `segment` em nenhuma migration; `capability-contract` só modela porte (MEI/ME/LTDA), não segmento | Cada cliente novo exigiria configuração manual repetida dos mesmos atributos |
| L5 | Nenhuma tela usa `establishment_id` — o multi-CNPJ funciona no banco, não na interface | `grep` em `src/features/*/components` não retorna nenhuma ocorrência de `establishment` | Cliente com múltiplas lojas/CNPJs (celular) não consegue operar individual+global ainda |
| L6 | Modelo de **representação/revenda de marca terceira** (iGreen Energy, Nipponflex — vocês como representante legal) não tem decisão nem desenho | Não é lacuna de código, é decisão de negócio ainda não tomada | Ver seção 4 — decisão sua antes de qualquer schema |

## 3. Matriz de prontidão

| Área | Estado | Condição para avançar |
|---|---|---|
| Estrutura multiempresa (tenant→establishments) | Pronto no banco | Construir seletor individual/global na UI (M20-G4) |
| Segmentos oficina/restaurante | Pronto no banco, sem dado real | Nenhuma ação de schema; só entra dado real depois do M20 fechar |
| Extensibilidade por atributo (EAV) | Pronto no banco | Precisa de um registro de "segmento → atributos obrigatórios" (M20-G2) |
| Fiscal por item | **Não existe** | Migration nova + validação ligada ao `fiscal-contract` (M20-G1) |
| Comercial por item (custo/margem/estoque mínimo) | **Não existe** | Migration nova (M20-G1) |
| Telas de cadastro completas | Esqueleto | Reescrever formulários com abas, igual ao padrão do legado (M20-G3) |
| Representação de marca terceira | Sem decisão | Você decide o modelo em M20-G5 antes de qualquer schema |

## 4. Decisão — representação legal (iGreen / Nipponflex) — RESOLVIDA (07/09/2026)

**Opção C escolhida — tenant próprio, um por marca (2 tenants separados).** iGreen Energy e
Nipponflex viram dois tenants distintos, cada um dono da ConnectionCyber, cada um com seu
próprio estoque/vendas/financeiro isolado — tratados como dois clientes normais do sistema, não
como fornecedor dentro de outro tenant. Faz sentido porque as contabilidades das duas marcas são
separadas (CNPJs/operações diferentes), não uma linha de produto dentro da mesma empresa.

Isto **não exige schema novo** — o modelo multi-tenant já suporta isso (é o mesmo mecanismo que
atende Mania de Modas ou qualquer outro cliente). M20-G5 fica reduzido a: provisionar os dois
tenants (`pilot-igreen`, `pilot-nipponflex` ou nomes equivalentes) quando chegar a vez deles,
seguindo o mesmo processo do §9 do `STATUS-MESTRE-DESENVOLVIMENTO.md` — não entra na fila antes
de Mania de Modas, é só mais um cliente na fila de onboarding.

~~Opções A (fornecedor especial dentro de outro tenant) e B (catálogo de marca dedicado)~~ —
descartadas: não se aplicam a uma estrutura contábil separada.

## 5. Sequência determinística M20

Segue o mesmo formato dos módulos anteriores (M14/M15/M16): cada portão só libera o próximo
depois de teste local aprovado; nada toca Supabase remoto antes do preflight; produção
permanece fora de escopo o tempo todo.

| Portão | Entrega | Estimativa | Intervenção necessária |
|---|---|---|---|
| M20-G0 | Este parecer — auditoria, lacunas, decisão de segmento e representação | Feito (hoje) | Sua leitura e aceite |
| M20-G1 | Migration `0037`: campos fiscais + comerciais em `erp_catalog_items` (ou tabela satélite `erp_item_fiscal_data` / `erp_item_commercial_data`, a definir por normalização), preflight, rollback, pgTAP | 3-4h | Nenhuma até preflight local passar |
| M20-G2 | Tabela `erp_business_segments` + `erp_segment_attribute_requirements` ligando segmento a atributos EAV obrigatórios/opcionais; seed com a lista confirmada na seção 6 | 2-3h | Nenhuma — lista já confirmada em 07/09/2026 |
| M20-G3 | Reescrita das telas de cadastro (`PartyForm`, `ItemForm`) em abas — Dados/Documentos/Contatos/Endereços para pessoa; Geral/Fiscal/Comercial/Estoque/Atributos do segmento para produto — replicando a cobertura de campo do SICNET | 1-2 dias | Revisão visual sua ao final (é a parte que você vai usar todo dia) |
| M20-G4 | Seletor de estabelecimento (individual/todos) nas telas que já têm `establishment_id` no banco (estoque, vendas, OS) | 4-6h | Nenhuma até preflight local passar |
| M20-G5 | Provisionamento dos tenants iGreen e Nipponflex (2 tenants, Opção C — sem schema novo), entram na fila de onboarding depois de Mania de Modas | 30min de schema (nenhum) + tempo normal de onboarding por cliente | Desbloqueado — decisão já tomada em 07/09/2026 |
| M20-G6 | pgTAP completo (schema + RLS + regressão dos módulos M05/M06/M09/M10 que dependem de `erp_catalog_items`), preflight, dry-run, rollback | 3-4h | Nenhuma até tudo verde local |
| M20-G7 | Aplicação da `0037` **somente em staging**, verificação pós-aplicação, checkpoint, atualização do `STATUS-MESTRE-DESENVOLVIMENTO.md` | 1h | Seu aceite formal para aplicar em staging (produção nunca entra aqui) |

Total estimado M20 completo: **3 a 4 dias úteis de trabalho técnico**, a maior parte no G3
(telas) porque é onde está o volume de campo, não a complexidade de banco.

**Só depois do M20-G7 fechado** faz sentido retomar M14/M15 (migração real da Mania de Modas) —
caso contrário, o dado real dela cai num cadastro sem campo fiscal e precisa ser retrabalhado.

## 6. Decisões fechadas (07/09/2026) — M20-G1 desbloqueado

As três confirmações pendentes foram resolvidas:

1. **Fiscal em tabela satélite** `erp_item_fiscal_data` (não dentro de `erp_catalog_items`) —
   segue o padrão que o schema já usa em `erp_party_documents`, `erp_item_identifiers`, etc.:
   nem todo item tem dado fiscal (serviço, taxa, vale não emitem NCM/CST), ciclo de vida fiscal
   muda independente do cadastro do produto, e permite RLS própria mais restrita.
2. **Representação de marca**: Opção C, 2 tenants (iGreen e Nipponflex) — ver seção 4.
3. **Lista de segmentos confirmada** para seed do `erp_business_segments` (M20-G2):

   | Segmento | Observação |
   |---|---|
   | Moda/vestuário | ex.: Mania de Modas |
   | Oficina (mecânica/CFTV/elétrica/solar) | M09 já cobre a base |
   | Restaurante/alimentação | M10 já cobre a base |
   | Papelaria | — |
   | Material de construção | — |
   | Celular (venda+reparo, multi-CNPJ) | usa M09 (reparo) + M07 (venda) + multi-estabelecimento |
   | Adega | — |
   | Casa de bolos (fabricação e venda) | usa `erp_item_compositions` (receita) + `erp_stock_lots` (validade) |
   | Loja de variedades | — |
   | Cabeleireiro e barbeiro | agendamento via M09 (`erp_appointments`) |
   | Perfumaria e cosmético | ref. Stillus Perfumaria auditada no G0 |
   | Loja de calçados | — |
   | Serviços ME/PF | genérico, sem estoque físico obrigatório |
   | Serviços de informática | idem |

Nenhuma migration, tela ou tabela foi criada ainda — G0 fecha aqui como só análise e decisão.
**M20-G1 (migration `0037`) está liberado para começar.**
