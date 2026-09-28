# Relatório de desenvolvimento controlado — staging

**Data:** 2026-08-18  
**Projeto:** `F:\Projetos\connectioncyber-staging`  
**Baseline:** branch `staging`, commit `188c08ecc2867e4c1bab6bcd248e9ed35d20534a`  
**Produção alterada:** não  
**Commit local:** criado ao final deste gate como ponto de rollback  
**Push, merge, deploy ou migration remota:** não realizados

## Resultado executivo

Os Gates 0 a 6 foram concluídos localmente. O site e o painel compilam com Next.js 15.5.21, os testes críticos de pagamento estão verdes e o audit npm de runtime terminou com zero vulnerabilidades nas duas aplicações.

O Mercado Pago está protegido por um kill switch: só pode operar quando `PAYMENTS_ENABLED=true`, o runtime é `VERCEL_ENV=production`, o access token existe e o segredo do webhook existe. Em desenvolvimento, preview e staging, checkout e APIs de pagamento permanecem desligados mesmo se uma credencial for inserida por engano.

## Baseline e preservação

- Alterações preexistentes preservadas: `icones/` e `modelo exemplo/`.
- Nenhum arquivo foi excluído.
- Nenhum segredo foi encontrado nos arquivos alterados ou novos.
- `git diff --check`: aprovado; apenas avisos de normalização LF/CRLF.
- O clone de produção não foi modificado.

## Mapeamento de ambientes observado

A documentação versionada define:

- Supabase produção: `qfggetvashdxyuvlhihq`.
- Supabase staging: `ozvylnaipubrmaadikvk`.
- Vercel Production deve usar produção.
- Vercel Preview/branch `staging` deve usar staging.
- `.env.local` deve apontar para staging por segurança, inclusive quando o arquivo está no clone local de produção.

O estado remoto da Vercel não foi alterado nem revalidado nesta execução.

## Alterações implementadas

### Isolamento de pagamentos

- Novo `PAYMENTS_ENABLED`, com default seguro `false`.
- Exigência simultânea de `VERCEL_ENV=production`.
- Checkout desabilitado fora de produção.
- APIs de criação de preferência e webhook retornam 503 fora de produção.
- `.env.local.example` documenta o kill switch.

### Autoridade financeira no servidor

- Navegador envia somente `id`, `type` e `quantity`.
- UUID, tipo, quantidade, duplicidade e propriedades extras são validados.
- Título, preço, moeda, estoque, status do catálogo, tenant e total são derivados no servidor.
- `userId`, preço e título informados pelo cliente não são aceitos.
- Cálculo financeiro usa centavos inteiros antes de converter o total.
- Em falha de criação da preferência, o pedido provisório é removido.

### Webhook Mercado Pago

- SDK atualizado para 3.4.0.
- Assinatura HMAC validada pelo SDK oficial.
- Janela contra replay de cinco minutos, compatível com timestamp em segundos ou milissegundos.
- Pedido e valor são reconciliados antes da atualização.
- Estado `pago` não é rebaixado por evento posterior pendente/recusado.
- Persistência idempotente por `(gateway, transaction_id)`.
- n8n recebe `Idempotency-Key`, autenticação Bearer opcional e timeout.
- Falha operacional retorna HTTP 500 para permitir retry.
- Confirmação da automação é registrada em `automation_notified_at`.

### APIs públicas

- Formulário de contato valida content type, tamanho e campos.
- Honeypot adicionado ao formulário.
- Rate limit transacional planejado em Supabase.
- Endereço IP é transformado em hash com `RATE_LIMIT_SALT`; IP puro não é persistido.
- n8n recebe identificador idempotente e token opcional.

### Segurança web

- CSP, Referrer-Policy, X-Content-Type-Options, X-Frame-Options e Permissions-Policy.
- HSTS somente em Production, sem `preload` ou `includeSubDomains` prematuros.
- Header `X-Powered-By` removido.
- Imagens de logo e clientes migradas para `next/image`.

### Dependências e runtime

- Next.js: `14.2.35` → `15.5.21` Maintenance LTS.
- Mercado Pago: `2.13.0` → `3.4.0`.
- PostCSS fixado em `8.5.26`.
- Sharp fixado em `0.35.0`.
- Node fixado em `>=22 <23`.
- Suporte prioritário a `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` e `SUPABASE_SECRET_KEY`.
- Fallback temporário mantido para `NEXT_PUBLIC_SUPABASE_ANON_KEY` e `SUPABASE_SERVICE_ROLE_KEY`.

### Qualidade

- ESLint configurado sem assistente interativo nas duas aplicações.
- Type-check configurado sem gravar cache incremental.
- Workflow `.github/workflows/quality.yml` criado para `staging` e pull requests.
- CI executa instalação imutável, testes, type-check, lint e build.

## Validações concluídas

| Validação | Site | Painel |
|---|---:|---:|
| Testes críticos | 5/5 aprovados | Não aplicável nesta etapa |
| TypeScript | Aprovado | Aprovado |
| ESLint | Aprovado, sem erros/avisos | Aprovado, sem erros/avisos |
| Build Next.js 15.5.21 | Aprovado | Aprovado |
| npm audit runtime | 0 vulnerabilidades | 0 vulnerabilidades |
| Scan local de secrets | Nenhum encontrado | Nenhum encontrado |

Smoke test do kill switch:

- `GET /checkout` → 200, pagamentos somente em produção.
- `POST /api/payments/create-preference` → 503 fora de produção.
- `POST /api/payments/webhook` → 503 fora de produção.

## Migrations locais ainda não aplicadas

### `0014_payment_webhook_hardening.sql`

- adiciona `payments.automation_notified_at`;
- cria unicidade em `(gateway, transaction_id)`.

Preflight obrigatório antes da aplicação:

```sql
select gateway, transaction_id, count(*)
from public.payments
where transaction_id is not null
group by gateway, transaction_id
having count(*) > 1;
```

O resultado precisa ser vazio. Se houver duplicidade, a migration deve parar para decisão humana; nenhum registro será apagado automaticamente.

### `0015_api_rate_limits.sql`

- cria `api_rate_limits` com RLS;
- remove acesso de `public`, `anon` e `authenticated`;
- cria RPC transacional acessível apenas por `service_role`.

## Variáveis necessárias por ambiente

### Preview / staging

- `NEXT_PUBLIC_SUPABASE_URL`: projeto `ozvylnaipubrmaadikvk`.
- `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`: chave publishable de staging.
- `SUPABASE_SECRET_KEY`: segredo de staging, somente servidor.
- `PAYMENTS_ENABLED=false`.
- Não cadastrar access token ou webhook secret de produção.
- `RATE_LIMIT_SALT`: valor aleatório exclusivo de staging.

### Production

- `NEXT_PUBLIC_SUPABASE_URL`: projeto `qfggetvashdxyuvlhihq`.
- `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`: chave publishable de produção.
- `SUPABASE_SECRET_KEY`: segredo de produção, somente servidor.
- `PAYMENTS_ENABLED=true` somente após migrations e checklist.
- `MERCADOPAGO_ACCESS_TOKEN`: credencial real rotacionada.
- `MERCADOPAGO_WEBHOOK_SECRET`: assinatura gerada no painel Mercado Pago.
- `RATE_LIMIT_SALT`: valor aleatório exclusivo de produção.
- `N8N_WEBHOOK_TOKEN`: se a automação exigir autenticação.

## Pendências externas — Gate 7

1. Revogar/rotacionar o token e contas de teste Mercado Pago expostos na conversa.
2. Confirmar no painel Vercel o mapeamento Production → `qfg...` e Preview → `ozv...`.
3. Configurar as novas variáveis sem remover imediatamente os fallbacks legados.
4. Executar o preflight de duplicidades no Supabase de staging.
5. Aplicar `0014` e `0015` primeiro no Supabase de staging.
6. Revalidar rate limiting e idempotência contra staging real, mantendo Mercado Pago desligado.
7. Revisar o diff e autorizar commit/push da branch `staging`.
8. Aguardar CI remoto e Preview Vercel.

## Gate 8 — produção

Somente após o Gate 7:

1. preflight no banco de produção;
2. backup/restauração verificáveis;
3. migrations em produção;
4. merge revisado para `main`;
5. deploy Vercel;
6. smoke test com pagamento desligado;
7. habilitar `PAYMENTS_ENABLED=true`;
8. transação real mínima autorizada;
9. verificar pedido, pagamento, webhook, idempotência, n8n e logs;
10. manter janela de rollback.

## Rollback

- Pagamentos: `PAYMENTS_ENABLED=false` e novo deploy.
- Aplicação: rollback do deployment Vercel ou reversão do commit de promoção.
- Banco: nenhuma migration remota foi executada nesta fase; rollback SQL deve ser aprovado separadamente caso as migrations sejam aplicadas.

## Pendência não bloqueante

`next lint` está depreciado no Next.js 15 e será removido no Next.js 16. O comando ainda funciona e está verde. Antes de uma futura migração para Next 16, substituir pelo ESLint CLI.
