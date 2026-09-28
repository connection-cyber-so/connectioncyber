# M18-G7 — agregados e composição persistente server-side

Data: 31/08/2026

## Resultado

- Implementados agregados tenant-scoped para financeiro e dashboard.
- Toda origem recebe `tenant_id` antes dos filtros funcionais.
- Dashboard combina empresas/partes, catálogo, estoque, vendas, caixa e títulos financeiros.
- Financeiro apresenta principais de contas a receber/pagar e situação das parcelas.
- Janela máxima de 5.000 linhas é fail-closed: resultado possivelmente truncado nunca é exibido como total.
- Criada fábrica server-side que compõe broker M18, adaptador Supabase, agregador e resolvedor de tenant.

## Controles

- A fábrica não cria cliente, não lê variáveis de ambiente e não escolhe tenant.
- Cliente Supabase e resolvedor de tenant precisam ser injetados pelo servidor.
- As seis superfícies visuais continuam importando exclusivamente o transporte sintético.
- Nenhuma credencial, rede ou serviço remoto foi utilizado.

## Evidências

- Adaptador e agregados: 23/23 testes.
- Plataforma e composição: 80/80 testes.
- Contrato visual: 49/49 testes.
- TypeScript: aprovado.
- ESLint: aprovado.
- Build Next.js com Node.js 22: aprovado.

Marcador: `M18_G7_PERSISTENT_COMPOSITION_LOCAL_OK`

Próximo gate: M18-G8 — auditoria final local do adaptador e preparação do ensaio somente leitura no Supabase staging; qualquer acesso remoto exigirá autorização específica posterior.
