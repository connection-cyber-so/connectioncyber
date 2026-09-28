# M21-G6 — extensão do provisionamento protegido pra "1 tenant, N estabelecimentos"

Data: 08/09/2026

Ambiente: local (Docker, stack Supabase local isolado) — **nenhuma escrita em staging real**

## Escopo

O provisionamento real usado pra Mania de Modas (M18-G21, `erp_prepare_pilot_provisioning_v1`,
migration `0034`) sempre cria um tenant novo — rodar a mesma função duas vezes pro mesmo
cliente falha com `pilot identity already exists`. Isso bloqueava o caso real da **Loja da
Benção** (MEI Aldo Augusto Ribeiro + MEI Eliane Aparecida Moreira Ribeiro), decidido em
`IMPLANTACAO-CASA-DE-BOLOS-MEI.md` como **1 tenant combinado, 2 estabelecimentos, 2 donos**
("uma coisa só" com abas, gerenciável individual e globalmente).

## Risco

- Escrita real em Supabase, formato/unicidade de CNPJ e IE, criação de identidade Auth —
  mesma classe de risco do M18-G21 original. Mitigado com o mesmo desenho fail-closed
  (advisory lock por idempotência, replay seguro, allowlist de campos, rejeição de segredo
  no payload) e testado antes de qualquer aplicação real.
- Nenhum dado real (CNPJ/e-mail dos clientes) tocou este gate — toda validação usou dado
  sintético (`.connectioncyber.invalid`, CNPJs `44444444444444`/`55555555555555`), igual ao
  padrão já usado pelos testes do M18.

## Critério de aceite

1. Nova função `erp_prepare_pilot_establishment_v1(p_tenant_slug, p_request)` anexa um
   estabelecimento (+ dono) a um tenant já existente, sem recriar tenant/papéis/capacidades.
2. Reaproveita **sem alteração** `erp_record_pilot_auth_identity_v1` e
   `erp_finalize_pilot_identity_v1` (já testadas no M18) — zero código novo no caminho de
   Auth/membership.
3. Mesmas garantias do M18: só `service_role` executa, payload allowlist, replay
   idempotente/seguro, CNPJ globalmente único, chave protegida/segredo rejeitada.
4. Testes locais (pgTAP) aprovados antes de qualquer aplicação remota.

## Achado durante a validação (corrigido no mesmo gate)

O índice único `erp_establishments_tenant_state_registration_unique` (M18, migration 0034)
trata o literal `'ISENTO'` como se fosse um número de IE real. Como até este gate nenhum
tenant tinha mais de um estabelecimento, essa colisão nunca tinha aparecido. Ao testar 2
estabelecimentos isentos de IE no mesmo tenant (cenário plausível pra Loja da Benção, se os
dois MEI acabarem sendo isentos), a inserção falhou:

```
ERROR: duplicate key value violates unique constraint
"erp_establishments_tenant_state_registration_unique"
DETAIL: Key (tenant_id, state_registration)=(..., ISENTO) already exists.
```

Corrigido na mesma migration 0042: o índice único agora exclui o literal `'ISENTO'`
(`where state_registration is not null and state_registration <> 'ISENTO'`), preservando a
garantia real (nenhum número de IE de verdade duplicado no mesmo tenant) sem impedir vários
estabelecimentos isentos de IE convivendo no mesmo tenant.

## Evidências

- Stack Supabase local (Docker, `supabase_db_connectioncyber`) recriado do zero
  (`supabase db reset --local`) com as 42 migrations, incluindo a 0042.
- Transação de validação (`supabase/validation/0042_transaction.generated.sql`, gerada por
  `build-0042-transaction.mjs`) executada via `psql` dentro do container local, em uma única
  transação `begin;...rollback;` — **nada commitado, nada persistido**.
- 22/22 asserções pgTAP aprovadas (8 estruturais + 14 adversariais/funcionais), marcador
  final: `M21_G6_0042_TRANSACTION_22_OF_22_ROLLBACK`.
- Cenário funcional coberto: tenant sintético com 1 estabelecimento (via função original do
  M18) → adição de um 2º estabelecimento + 2º dono no mesmo tenant → 2 estabelecimentos, 4
  passos duráveis, 1 convite pendente → replay idêntico reconhecido sem duplicar → replay
  divergente, CNPJ duplicado, tenant inexistente, vertical desconhecida, payload com segredo
  e chamador não-`service_role` todos rejeitados com o código de erro esperado.
- Stack local parado (`supabase stop`) ao final — ambiente devolvido ao estado anterior.

## Arquivos deste gate

- `supabase/migrations/0042_m21_g6_multi_establishment_pilot_provisioning.sql`
- `supabase/preflight/0042_m21_g6_multi_establishment_pilot_provisioning_preflight.sql`
- `supabase/tests/0042_m21_g6_multi_establishment_pilot_provisioning.test.sql`
- `supabase/tests/0042_m21_g6_multi_establishment_pilot_provisioning.adversarial.test.sql`
- `supabase/rollback/0042_m21_g6_multi_establishment_pilot_provisioning.rollback.sql`
- `supabase/validation/build-0042-transaction.mjs`

## Ambiente / efeitos remotos

Nenhum. Este gate rodou inteiramente num stack Supabase local descartável (Docker). A
migration `0042` **ainda não foi aplicada em staging real** (`ozvylnaipubrmaadikvk`) — isso
é o próximo passo, junto da aplicação real do provisionamento de Casa de Bolos e Loja da
Benção, e depende de credencial que este ambiente de execução não tem (ver bloqueio abaixo).

## Bloqueio para aplicar em staging real

- O conector Supabase MCP desta sessão está preso a um projeto de outra conta
  (`portal-teologico-os`), não ao projeto ConnectionCyber staging — mesmo problema já
  registrado pro Vercel MCP.
- A Supabase CLI local está linkada ao projeto certo (`ozvylnaipubrmaadikvk`) mas sem sessão
  autenticada válida (`Unauthorized` em `supabase projects list`) — precisa de um **legacy
  token** gerado pelo usuário (gotcha já documentado: tokens *fine-grained* não funcionam em
  `supabase link`/`db push`; ver memória `external-accounts-reference`).
- Falta ainda a Inscrição Estadual (ou confirmação de isenção) de Aldo e de Eliane pra
  completar os dados de provisionamento da Loja da Benção — só a da Casa de Bolos
  (`626873540110`) foi confirmada até agora.

## Decisão

**APROVADO EM AMBIENTE LOCAL — aguardando credencial + IE restante para aplicar em staging
real.** Próximo portão: aplicar `0042` em staging (`supabase db push` com token válido),
depois executar o provisionamento real de Casa de Bolos (dados completos) e Loja da Benção
(falta IE de Aldo/Eliane).
