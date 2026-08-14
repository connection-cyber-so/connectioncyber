# ConnectionCyberSO — Parecer Técnico de Arquitetura #001

**Um Supabase para todos, ou um por cliente?**
Avaliação da reestruturação de pastas/repositórios, isolamento entre clientes e estratégia
multi-tenant — decisão tomada em 2026-08-12, roteiro executado ao longo desta mesma sessão.

> Este documento registra a **decisão** e o **roteiro planejado**. O estado de execução real
> (o que já foi feito) vive em `README.md` (raiz do monorepo) e em
> `docs/auditoria-ecossistema-connectioncyberos.md` — este parecer não é reescrito a cada etapa
> concluída, fica como registro da decisão original.

## 1. Ambiguidades na estrutura de pastas proposta

A mensagem original descrevia o layout de duas formas conflitantes:

- **Staging**: ora como pasta aninhada (`connectioncyber\staging`), ora como pasta irmã
  (`connectioncyber-staging`, confirmado pelos comandos `cd` fornecidos).
- **Cliente futuro** (ex: Mania de Modas): mesmo conflito — `connectioncyber-maniademodas\staging`
  (irmã) vs. `connectioncyber\maniademodas\site` (aninhada).

**Decisão confirmada**: pastas irmãs, não aninhadas — um clone Git dentro de outro clone Git é
fonte comum de confusão (editores indexando os dois, `.gitignore` de um vazando pro outro).

## 2. A pergunta central: 1 Supabase para todos, ou 1 por cliente?

Três opções reais:

| Opção | Como funciona | Rotina nova em todos os clientes | Isolamento |
|---|---|---|---|
| **A — Plataforma única** (recomendada) | 1 Supabase, tabela `tenants` + `tenant_id` + RLS | 1 deploy — vale para todos na hora | Lógico (RLS), forte na prática |
| B — Um projeto por cliente | N Supabase, N Vercel, N repositórios | N deploys — reaplicar manualmente em cada um | Físico, total |
| C — Schema por cliente | 1 Supabase, N schemas Postgres | Meio-termo — ainda roda N vezes | Mais forte que RLS, atrito operacional maior |

**Opção A escolhida.** Justificativa: o custo de crescer (adicionar um cliente) é uma linha na
tabela `tenants`, não uma infraestrutura inteira nova. A rotina fiscal/cadastro comum entra uma
vez no código da plataforma e vale para todos os clientes automaticamente.

## 3. Isolamento — como um cliente nunca vê o outro

Seis camadas, na ordem em que uma requisição passa por elas:

1. **Login** → JWT carrega o `tenant_id` do usuário (não escolhido por ele).
2. **API/servidor** → deriva `tenant_id` da sessão; nunca aceita `tenant_id` vindo do navegador.
3. **Postgres RLS** → compara `tenant_id` do token com o da linha, antes de devolver qualquer
   dado. Continua protegendo mesmo se a API tiver um bug — o isolamento não depende só do código
   estar certo.
4. **Storage** → arquivos em `tenants/<id>/...`, RLS própria.
5. **Auditoria** → `logs_access`/`remote_logs` registram tentativas negadas, não só aceitas.
6. **Admin (equipe ConnectionCyber)** → cruza tenants quando precisa, mas cada uso fica
   registrado (modo "quebra-vidro", não acesso livre por padrão).

## 4. Atualizar tudo de uma vez, ou por cliente?

Não é ou-ou — depende do que está mudando:

- **Estrutura do banco** (coluna/tabela nova) é sempre global nesta opção — toda migration é
  aditiva e passa pelo branch de staging antes de tocar produção.
- **Regra de negócio** (a rotina em si) fica atrás de uma **feature flag por tenant** — liga-se
  primeiro para um cliente piloto, valida, depois liga geral. Mesmo código, mesmo banco,
  exposição controlada.

## 5. Particularidades de cliente sem duplicar o sistema

| O que foi descrito | Vira, no modelo recomendado | Exemplo |
|---|---|---|
| Requisito Customizado / Demanda de Nicho / Escopo Específico | Configuração por tenant (`tenant_settings`, campo `jsonb`) | Grade de tamanho BR em vez de numérico |
| Segmentação de Mercado | O `vertical` do tenant carrega módulos diferentes | Cliente de food vê cardápio; varejo não |
| Divergência/Assimetria Operacional | Módulo opcional plugável, ligado via feature flag | Aprovação de compra em 3 níveis vs. 1 |
| Particularidade do Modelo de Negócio | Tier/plano comercial | Plano "Enterprise" libera relatório avançado |

Gatilho real para sair da Opção A: **exigência jurídica/contratual de isolamento físico por
escrito** de um cliente específico — não uma diferença de processo.

## 6. Estrutura final confirmada

```
connectioncyber            produção · branch main
├─ apps/
│  ├─ site/                site institucional
│  └─ platform/             ConnectionCyberSO — ERP/CRM/SaaS
├─ packages/
│  └─ core/                 cadastros, rotinas fiscais — compartilhado
└─ supabase/migrations/

connectioncyber-staging    staging · branch staging (2º clone do mesmo repositório)
```

```
GitHub (1 repo, 2 branches)
        │
        ├── branch main    → Vercel Produção  ──┐
        └── branch staging → Vercel Staging   ──┤
                                                  ▼
                                    Supabase — 1 projeto único
                                                  │
                                    tabela tenants + RLS
                                    ┌────────────┼────────────┐
                              ConnectionCyber  Mania de Modas  próximo cliente
```

Cliente novo = uma linha em `tenants` + um domínio. Nenhuma pasta, repositório ou banco novo
nasce por cliente — exceto se algum dia um cliente exigir isolamento físico contratual, caso em
que ganha um Supabase dedicado, fora do padrão.

## 7. Roteiro executado

| Etapa | Descrição | Status |
|---|---|---|
| 00 | Este parecer | ✅ concluída |
| 01 | 3 decisões confirmadas | ✅ concluída |
| 02 | Reorganizar pastas locais em monorepo | ✅ concluída |
| 03 | Git + GitHub (init, branches, clone de staging) | ✅ concluída — GitHub desbloqueado, `main` e `staging` sincronizados com `origin` |
| 04 | Supabase (link, migrations, tenants/RLS) | ✅ concluída — 4 migrations aplicadas |
| 05 | Vercel (ambientes Produção/Staging) | ✅ concluída — deploy de produção validado |
| 06 | Validação de build/deploy | ✅ concluída |
| 07 | Início do `apps/platform` (ConnectionCyberSO) | ⬜ não iniciado |

Ver `README.md` (raiz) para o status vivo, e `docs/auditoria-ecossistema-connectioncyberos.md`
para os padrões trazidos de outros projetos do ecossistema depois desta decisão.
