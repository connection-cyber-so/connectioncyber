# ConnectionCyber — Pacote técnico M04-G1

## Identidade, RBAC, MFA e provisionamento em dry-run

**Ambiente de desenvolvimento:** `connectioncyber-staging`

**Data:** 19/08/2026

**Versão:** 1.0.1

**Estado:** código, laboratório, CI e Preview aprovados; Supabase remoto inalterado

**Contas, convites, memberships, roles ou MFA criados:** zero

## 1. Resultado executivo

O M04-G1 está implementado como pacote revisável e deny-by-default. A migration
`0018` foi aplicada apenas em PostgreSQL 17.6 descartável, o provisionador aceita
somente `--dry-run`, e a tela interna permanece desabilitada para escrita.

Nenhuma chamada ao Supabase Admin API foi implementada. Supabase staging, Auth,
configurações Vercel, DNS e produção não foram alterados por esta etapa. A
integração existente gerou somente um Preview da branch `staging`.

## 2. Entregas

| Camada | Artefato | Comportamento |
|---|---|---|
| banco | `supabase/migrations/0018_identity_rbac_mfa_hardening.sql` | hardening de profile/JWT, lifecycle, MFA/AAL e ledger server-only |
| preflight | `supabase/preflight/0018_identity_rbac_mfa_hardening_preflight.sql` | somente leitura; recusa colisão, lacuna de profile e histórico 0018 existente |
| rollback | `supabase/rollback/0018_identity_rbac_mfa_hardening.rollback.sql` | apenas laboratório vazio com duas confirmações explícitas |
| pgTAP | `supabase/tests/0018_identity_rbac_mfa_hardening.test.sql` | 49 asserções transacionais |
| manifesto | `apps/platform/fixtures/identity-provisioning.example.json` | sete personas sintéticas em `.invalid` |
| provisionador | `apps/platform/scripts/identity-provisioning.mjs` | validação e plano determinístico sem rede ou escrita |
| testes | `apps/platform/tests/identity-provisioning.test.mjs` | 9 casos unitários |
| tela | `apps/platform/src/app/(painel)/identidades/page.tsx` | convite, usuários, papéis e MFA somente demonstrativos |
| CI | `.github/workflows/quality.yml` | inclui `npm test` no job `platform` |

SHA-256 da migration apresentada:

`e8bf56d6f69a5acb50f2434f40b406bb8ad5e7322ea2890462bcfa53b291e659`

## 3. O que a migration 0018 altera

### 3.1 Identidade e profile

- `public.users.tenant_id` torna-se nullable e permanece apenas como ponte legada;
- `handle_new_user()` ignora `tenant_id` de `raw_user_meta_data` e não usa fallback;
- `custom_access_token_hook()` remove a claim legada `tenant_id` e preserva as demais;
- funções `security definer` recebem `search_path` vazio;
- usuário autenticado lê o próprio profile e atualiza somente `nome` e
  `idioma_preferido`;
- `email`, `tenant_id`, `ativo` e identidade não podem ser alterados pelo cliente.

### 3.2 Membership, RBAC e MFA

- lifecycle recebe datas de convite, ativação, suspensão, revogação e expiração;
- roles ERP recebem `requires_mfa` e sensibilidade `standard/privileged`;
- cinco permissões são adicionadas: `identities.read`, `identities.manage`,
  `roles.assign`, `mfa.read` e `mfa.enforce`;
- `current_aal()` normaliza a sessão em `aal0`, `aal1` ou `aal2`;
- `has_permission_at_aal()` exige membership ativa, permissão e AAL mínimo.

### 3.3 Ledger de provisionamento

As tabelas `erp_identity_provisioning_runs` e
`erp_identity_provisioning_steps` registram idempotência, hash do manifesto,
correlação, passos, retomada e compensação. Elas possuem RLS sem policy para
cliente: somente `service_role` poderá acessá-las por uma API futura auditada.

Campos JSON recusam chaves com indícios de senha, token, segredo, credencial,
certificado ou PFX.

## 4. Provisionador bloqueado em dry-run

O executável recusa `--apply`, ambiente diferente de staging, e-mail real,
e-mail transitório fora de `.invalid`, segredo, duplicidade, papel fora da
allowlist e owner/admin sem MFA.

Resultado do manifesto oficial:

```text
subjects:       7
executionMode:  dry_run
executable:     false
networkCalls:   0
databaseWrites: 0
manifest hash:  ea9c637920ec3ce14138a98999e4bf51c337dc069f391fd954e7d71cd7f03226
idempotency:    identity:staging:m04-g1-personas:ea9c637920ec3ce1
```

## 5. Representação das telas

```text
┌────────────────────────────────────────────────────────────────────┐
│ Identidades, papéis e MFA                         DRY-RUN OBRIGATÓRIO│
├────────────────────────────────────────────────────────────────────┤
│ [7 personas] [0 contas] [5 papéis] [AAL2 privilegiado]             │
├────────────────────────────────────────────────────────────────────┤
│ Convite: e-mail controlado → empresa → papel → expiração → MFA     │
│                                      [ SOMENTE DRY-RUN — DESABILITADO ]│
├────────────────────────────────────────────────────────────────────┤
│ Usuários: P01 owner A | P03 multiempresa | P05 suspenso | P06 convite│
├────────────────────────────────────────────────────────────────────┤
│ owner/MFA │ admin/MFA │ manager │ operator │ viewer                │
├────────────────────────────────────────────────────────────────────┤
│ AAL1 → ação bloqueada → validar TOTP → AAL2 → ação + auditoria      │
└────────────────────────────────────────────────────────────────────┘
```

A rota `/identidades` foi adicionada ao painel interno e compilada como página
server-rendered. Seus controles estão desabilitados e não existe action/route de
gravação associada.

## 6. Testes e evidências locais

| Prova | Resultado |
|---|---:|
| provisionador Node | 9/9 |
| M02 regressão pgTAP | 38/38 |
| M03 regressão pgTAP | 35/35 |
| M04 pgTAP | 49/49 |
| M04 após rollback/rebuild | 49/49 |
| TypeScript platform | aprovado |
| ESLint platform | zero warning/erro |
| build Next.js | aprovado; rota `/identidades` presente |
| preflight M04 | `M04_PREFLIGHT_OK` |
| rollback sem confirmação | recusado corretamente |
| rollback confirmado em laboratório vazio | aprovado; M03 preservado |
| resíduos no laboratório | `0|0|0|0|0` |

O fixture M02 deixou de depender de `email_confirmed_at`, ausente em algumas
versões do schema Auth. O fixture M03 agora prepara explicitamente o tenant
legado, pois a partir da 0018 metadata não possui autoridade.

## 7. Incidente evitado no laboratório

A primeira compilação SQL da 0018 recusou `auth.jwt()`, indisponível na imagem
base usada. A transação reverteu integralmente. O helper foi tornado portátil
com `request.jwt.claims`, seguido de preflight, reconstrução e 49/49 testes.

## 8. Limites e riscos residuais

Checkpoint `72b1e0a` publicado exclusivamente em `origin/staging`. O Quality
Gate `32212844513` aprovou `site`, `platform` e `portal`; o deployment Vercel
`dpl_DKNCxPwYHidoC1mmdYNcwjP3YEB4` ficou `Ready` e o alias de staging respondeu
HTTP 200. A branch `main` permaneceu em `59a3924`.

- a migration 0018 não está no Supabase staging;
- configuração Auth continua com política anterior até portão remoto específico;
- TOTP continua desligado e nenhum fator foi criado;
- nenhum alias UAT foi validado ou convidado;
- nenhum catálogo de roles foi materializado por tenant;
- o provisionador não possui modo apply neste portão;
- inspeção visual automatizada ao vivo ficou indisponível por falha interna de
  confiança do recurso de navegador; compilação, responsividade CSS e estrutura
  da tela foram validadas, sem simular uma aprovação visual inexistente.

## 9. Próximo portão determinístico

O próximo aceite poderá aplicar somente a migration 0018 no Supabase staging e
executar validação remota. Continuará proibido criar identidades ou ativar MFA.

> **M04-G1 pacote e laboratório aprovados; aplicar 0018 exclusivamente no Supabase staging e executar validação remota, sem criar contas, convites, memberships, roles ou fatores MFA.**
