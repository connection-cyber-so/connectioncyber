# M20-G3 — Telas em abas: documento/contato/endereço + fiscal/comercial/atributos

Data: 07/09/2026

Executado sem interferência do usuário, a pedido dele, junto com o M20-G4 na mesma sessão.

## Escopo real encontrado antes de escrever qualquer tela

`apps/platform` (painel) não fala com o Supabase real hoje — todo leitura/escrita das telas
`/cadastros`, `/catalogo`, `/operacoes` e `/pdv` passa por um transporte único
(`visualPersistenceClient`, `packages/visual-persistence-contract`), que resolve pra um de dois
modos: `synthetic` (dado fake em memória do servidor, some ao reiniciar) ou
`persistent-read-only` (lê Supabase de verdade, mas **toda escrita é bloqueada** — regra do
M18-G11/G12, não deste módulo). Hoje o ambiente roda em `synthetic` por padrão
(`.env.local.example`). Isto não é uma limitação desta gate — é a arquitetura já existente, e
`party.create`/`catalog.item.create` já funcionavam exatamente assim antes do M20 começar.

Consequência prática: as abas novas tinham que se conectar a este MESMO transporte pra
funcionar de verdade (criar/consultar dado real seria simplesmente impossível nesta tela hoje,
independente do M20) — não dava pra simplesmente escrever formulário bonito sem religar o
contrato por trás.

## Contrato de comandos — bump de versão explícito, não mutação silenciosa

`packages/visual-persistence-contract` trava a versão do contrato
(`CONTRACT_VERSION`) e os testes conferem contagem exata de comandos/read models — o M18-G5
tinha fechado em **7 comandos, 11 read models, versão `M18-VISUAL-1.0`**, com testes que
comparam esses números um por um. Expandir isso pra caber documento/contato/endereço de pessoa e
fiscal/comercial de item exigia adicionar comandos a essa superfície já auditada.

Decisão: tratar como um **bump de versão** (`M20-VISUAL-2.0`), não uma edição do M18. Adicionados:

| Comando novo | RPC (nome reservado, sem função real ainda) | Tela |
|---|---|---|
| `party.document.add` | `erp_command_add_party_document_v1` | `/cadastros` |
| `party.contact.add` | `erp_command_add_party_contact_v1` | `/cadastros` |
| `party.address.add` | `erp_command_add_party_address_v1` | `/cadastros` |
| `catalog.item.fiscal.set` | `erp_command_set_item_fiscal_data_v1` | `/catalogo` |
| `catalog.item.commercial.set` | `erp_command_set_item_commercial_data_v1` | `/catalogo` |
| `establishment.vertical.set` | `erp_command_set_establishment_vertical_v1` (M20-G4) | `/operacoes` |

7→13 comandos, 11→19 read models (8 novos: `party-documents`, `party-contacts`,
`party-addresses`, `item-fiscal-data`, `item-commercial-data`, `business-verticals`,
`vertical-attribute-requirements`, `establishments`). Os 10 controles do `THREAT_MODEL`
(T01-T10) são genéricos do pipeline `execute()`/`read()` — tenant resolvido no servidor,
idempotência por hash, screening de campo de autoridade/segredo, releitura obrigatória — e
valem automaticamente pra todo comando novo, sem exceção nem revisão caso a caso.

`packages/visual-persistence-supabase-adapter` ganhou os `READ_PLANS` correspondentes (pra
quando o modo `persistent-read-only` mostrar dado real de fiscal/comercial/vertical/
estabelecimento). `business-verticals` e `vertical-attribute-requirements` são catálogo global
(sem `tenant_id`, mesmo padrão de `erp_segment_profiles`/`erp_permissions`) — o adaptador ganhou
um caminho `global:true` que pula o filtro de tenant nesses dois, sem enfraquecer o filtro nos
outros dezessete. **Nenhuma função RPC real foi criada no Supabase para os comandos novos** — o
`RPC_ALLOWLIST` do adaptador não lista nenhum deles, então em modo `persistent-read-only`
qualquer tentativa de usar esses comandos falha fechado (`ADAPTER_RPC_BLOCKED`), igual já
acontecia com os 7 originais nesse modo.

## Telas

- **`/cadastros`**: cada cadastro ganhou um painel expansível (`<details>` nativo do HTML, sem
  JS de navegação) com três seções — Documentos, Contatos, Endereços — cada uma com lista dos
  já cadastrados + mini-formulário pra adicionar mais um, sempre atrelado à pessoa já criada.
- **`/catalogo`**: cada item ganhou o mesmo padrão — Fiscal (NCM/CEST/origem/CST-CSOSN/
  alíquotas/peso), Comercial (custo/margem/preço sugerido/estoque mínimo/reposição) e Atributos
  do segmento.
- **Atributos do segmento é informativo por enquanto**: mostra quais campos a vertical do
  estabelecimento ativo exige (M20-G2), mas não grava ainda em `erp_attributes`/
  `erp_item_attribute_values` reais — a materialização por tenant continua sendo trabalho de um
  portão de provisionamento futuro, exatamente como o `RELATORIO-M20-G2-VERTICAIS-SEGMENTO.md`
  já tinha declarado. Não é um corte novo desta gate, é o mesmo limite já combinado.

## Por que `<details>`, não abas de JavaScript

O padrão já estabelecido no app (M19-G4: "mesmo idioma 100% servidor + formulário sem JS") pesou
na decisão — `<details>`/`<summary>` é HTML nativo, zero JavaScript de navegação, funciona sem
hidratação e é acessível por padrão. Os formulários dentro de cada seção continuam client
components com `useFormState`/`useFormStatus` (igual ao `PartyForm`/`ItemForm` originais) só pra
UX de pendência (`disabled={pending}`), não pra abrir/fechar aba.

## Validação

- `tsc --noEmit`: limpo.
- `next lint`: limpo.
- `next build`: sucesso, todas as rotas compiladas.
- `node --test tests/*.test.mjs`: **179/179** (165 já existentes, sem regressão + 14 novos
  cobrindo os comandos/read models novos, os painéis de detalhe e a ausência de JS de
  navegação por aba).
- `packages/visual-persistence-contract`: 52/52 (46 já existentes + 6 novos).
- `packages/visual-persistence-supabase-adapter`: 51/51 (44 já existentes + 7 novos).

## O que NÃO foi feito nesta gate

- Nenhuma função RPC real criada no Supabase para os 6 comandos novos — continuam só no modo
  `synthetic`. Habilitar escrita real é decisão do M18 (persistência), fora do escopo do M20.
- Materialização de atributo de vertical em `erp_attributes` real por tenant.
