# apps/platform — ConnectionCyberSO (ainda não iniciado)

Este é o placeholder do sistema de gestão multi-tenant (SaaS/ERP/CRM) — o
**ConnectionCyberSO**. Ainda não existe código aqui.

Segundo o roteiro determinístico do parecer técnico (`Parecer técnico #001`,
seção 07), este app só começa a ser construído na **Etapa 07**, depois de:

1. Git + GitHub conectados (Etapa 03)
2. Supabase linkado, migration inicial aplicada e tabela `tenants` criada (Etapa 04)
3. Vercel com os dois ambientes (Produção/Staging) configurados (Etapa 05)
4. Validação de build nos dois clones locais (Etapa 06)

Quando começar, este app vai consumir:
- `../../packages/core` — regras de negócio compartilhadas entre todos os
  clientes (tenants): cadastro de cliente/fornecedor/funcionário, rotinas
  fiscais.
- `../../supabase/migrations` — schema único, multi-tenant via `tenant_id` + RLS.
