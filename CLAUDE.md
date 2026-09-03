# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Custom Instructions: ADHD-Friendly Output

O desenvolvedor lendo isso tem TDAH. Formate TODAS as respostas para que um cérebro com TDAH possa agir imediatamente.

**Regras Absolutas:**
1. **Comece com a próxima ação:** A primeira linha DEVE ser um comando, caminho ou snippet de código. Zero preâmbulos.
2. **Numere tarefas com múltiplas etapas:** Use listas numeradas curtas. Um passo = uma ação isolada. Máximo de 5 itens por lista.
3. **Seja Direto:** Sem frases como "Great question!", "Hope this helps!" ou "Let me think about this". Remova fechamentos.
4. **Estimativas Exatas:** Dê estimativas de tempo específicas (minutos), nunca "um pouco" ou "algumas horas".
5. **Estado Visível:** Reafirme o progresso e externalize o estado a cada interação.

## Repo identity

This clone is **`connectioncyber-staging`** — the `staging` branch working copy, always a
sibling clone of the `main` (production) repo, never nested inside it. `docs/` (long-form
architecture docs) lives only on `main`; this clone does not version it. The many
`RELATORIO-*`, `PARECER-*`, `VALIDACAO-*`, `AUDITORIA-*` root-level `.md` files are the
per-gate technical reports required by the governance process below — check one by module/gate
code (e.g. `M18-G21`) before assuming a module's state is unknown.

**Read `GOVERNANCA-EXECUCAO-AUTOMATICA.md` and `STATUS-MESTRE-DESENVOLVIMENTO.md` before
starting any non-trivial task.** They are the persistent operating rules for this project and
survive context compaction / new sessions — re-consult them, don't rely on memory of a prior
session. Summary:

- Work only proceeds in `connectioncyber-staging`; production changes require separate explicit
  authorization and checklist.
- Deterministic sequence per module/gate: scope+risk+acceptance criteria recorded → dependencies
  checked → implement in staging → tests/lint/build/security proportional to risk → validate in
  staging/Preview → update `STATUS-MESTRE-DESENVOLVIMENTO.md` (both `.md` and `.html`) →
  checkpoint commit → only then evaluate promotion. A failed step keeps the module at the same
  gate — no silent workaround, no automatic data deletion, no silent production change.
  `STATUS-MESTRE-DESENVOLVIMENTO.md` §4 has the approved architecture, §7 the module/gate
  roadmap.
- During automated execution, only surface `GATE_EM_EXECUCAO`, blocking decisions, and
  `GATE_CONCLUIDO` — suppress narration of intermediate commands/retries. Ask for human
  intervention only for protected credentials, material decisions, remote writes, real identity
  data, production, or destructive actions.
- Every gate gets its own technical report file at repo root following the `RELATORIO-Mxx-Gy-...`
  / `PARECER-TECNICO-Mxx-...` naming pattern already in use.

## Commands

There is **no root `package.json`** — this is not an npm/pnpm workspace. Each app under `apps/*`
and each package under `packages/*` is independent with its own `package.json`,
`node_modules`, and `package-lock.json`. Always `cd` into the specific app/package first.

All apps and packages pin Node `>=22 <23` and every `dev`/`test`/`build` script runs
`scripts/check-node-version.mjs` as a `pre*` hook — a non-22 Node fails fast with
`NODE_VERSION_BLOCKED`.

```bash
cd apps/platform && npm install && npm run dev   # :3011 — internal panel (App Router)
cd apps/portal   && npm install && npm run dev   # :3021 — customer ERP portal (App Router)
cd apps/site     && npm install && npm run dev   # :3000 — public site (Pages Router)
```

Per app/package: `npm run build`, `npm run lint`, `npm run type-check` (`tsc --noEmit`), `npm test`.

- `apps/platform` tests: `node --test tests/*.test.mjs` (JS test files).
- `apps/portal` tests: `tsx --test tests/*.test.ts` (TS test files).
- `apps/site` tests: `node --test tests/*.test.mjs`.
- `packages/*` tests: `node --test tests/*.test.mjs` (each package is `"type": "module"`, plain
  `.mjs`, no bundler/TS build step — import straight from `./src/index.mjs`).
- Run a single test file directly, e.g. `node --test tests/some.test.mjs` from inside that
  app/package directory (no test runner config to target a single test another way).

Local dev and CI always point at the **staging** Supabase project, never production — see
`.env.local.example` in each app. `apps/platform` additionally requires `@google/genai` creds
for its AI features (diagnostics, offer copy, video scripts); `apps/portal`/`apps/site` don't.

Several `packages/*` expose one-off `simulate`/`validate` scripts tied to specific gates (e.g.
`packages/fiscal-contract`'s `sefaz:simulate`, `nfe:authorization`, `pilot:preflight`); check
that package's `package.json` `scripts` block before writing a new one — the gate this task
maps to likely already has a script.

## Architecture

### Three independent Next.js apps, one shared Supabase project

Single multi-tenant Supabase project (`ozvylnaipubrmaadikvk` in staging), isolation via
`tenant_id` + Row Level Security — no per-client project/repo/folder, a new client is a row in
`tenants`.

- **`apps/site`** (Pages Router, port 3000): public marketing site + student/member area
  (`/membros`) + checkout (Mercado Pago). No tenant-sensitive data.
- **`apps/platform`** (App Router, port 3011): internal staff panel — tenants, AI-assisted
  modules (diagnostics, product catalog, offers, video scripts, landing pages), rollout
  controls. Staff-only: `(painel)/layout.tsx` calls `is_platform_staff()` and blocks non-staff
  before rendering any menu/module. `middleware.ts` protects everything except `/login`, using
  `supabase.auth.getUser()` (validates the JWT against Supabase each request — never
  `getSession()`, which only trusts the cookie).
- **`apps/portal`** (App Router, port 3021): the customer-facing multi-company ERP. Access
  requires ALL of: exact/active/verified hostname → active tenant → `auth.getUser()` →
  active/current membership owned by that user → membership tenant matches hostname tenant.
  Legacy `users.tenant_id`, client-sent values, and the `cc_portal_membership` cookie never
  authorize access alone; staff gets no bypass here.

The three apps intentionally do **not** converge on one stack — each app's README documents its
own routing-model decision. Don't "fix" `apps/site` to App Router or vice versa without reading
that history first.

### `apps/platform` feature-module pattern

Business modules live under `src/features/<module>/` as `actions.ts` (Server Actions),
`service.ts` (data access), `types.ts`, `validations.ts`, `components/`. Server Components query
Supabase directly (no API-route layer to forget to protect). The tenant/user is always derived
server-side from the session (`src/lib/tenant.ts`: `getCurrentTenantId()` /
`requireCurrentTenantId()`, `src/lib/staff.ts`: `isPlatformStaff()`) — **never** from a form
field or query string; this was a real vulnerability fixed once already (`roles`/`user_roles`
missing RLS, migration `0013`). Supabase clients: `lib/supabase/client.ts` (browser),
`server.ts` (Server Components, reads cookies), `middleware.ts` (`updateSession()`, the
`@supabase/ssr` App Router pattern) — the same three-client split is used in `apps/portal`.

### `packages/*` — pure-logic contract packages, no framework

Each is a standalone Node `"type": "module"` package (`.mjs`, no build step, no TS compile) that
encodes the business/domain contract for one module gate and is unit-tested with `node --test`.
Apps consume these as the source of truth for validation/business rules rather than
re-implementing them:

- `fiscal-contract` — NF-e/SEFAZ (M13): SOAP/TLS, A1 certificate custody, authorization cycle,
  tax profiles, pilot preflight.
- `capability-contract` — per-tenant module/feature capability gating (M16), fail-closed engine.
- `import-contract` — legacy data import/idempotent ledger (M14).
- `persistent-journey-contract` — server-side authorized end-to-end journey contract (M17).
- `visual-persistence-contract` / `visual-persistence-supabase-adapter` — typed persistence
  contract (M18) plus its Supabase-backed implementation, kept separate so the contract can be
  validated read-only before any write adapter runs against real data.
- `device-protocol` — local peripheral/agent protocol (M12).
- `pilot-journey` — synthetic end-to-end pilot simulation/hypercare scripts (M15).
- `core` — shared cross-tenant business rules (scaffold only, see its README).

### Supabase: migration governance, not just `migrations/`

`supabase/migrations/*.sql` is one linear numbered schema (currently `0001`–`0034`) for the
single shared project. Every migration from `0029` on is expected to ship alongside matching
files in sibling folders — check for and add all that apply before considering a migration done:

- `supabase/preflight/<n>_..._preflight.sql` — read-only checks run before applying.
- `supabase/tests/<n>_....test.sql` (+ an `.adversarial.test.sql` for security-sensitive ones).
- `supabase/rollback/<n>_....rollback.sql` — forward-fix is preferred once applied remotely;
  destructive rollback is for disposable local labs only, per `apps/portal/README.md`.
- `supabase/verification/` / `supabase/diagnostics/` — post-apply / post-rollback verification
  queries, named by gate (`m18_g19_..._post_apply.sql`).
- `supabase/validation/*.mjs` — Node scripts that build the transaction for a migration
  (`build-00NN-transaction.mjs`) prior to remote apply.

`config/security-headers.js` defines the CSP/HSTS/frame headers shared by the Next.js apps
(stricter — no `'unsafe-eval'`, adds HSTS — when `VERCEL_ENV === 'production'`).
