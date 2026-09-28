# M18-G6 — adaptador PostgreSQL/Supabase local

Data: 31/08/2026

## Resultado

- Criado o pacote `@connectioncyber/visual-persistence-supabase-adapter`.
- Sete RPCs da migration `0033` formam uma allowlist fechada.
- Leituras usam seleção explícita, limite e filtro `tenant_id` aplicado antes de filtros funcionais.
- Fontes, RPCs, contratos ou respostas desconhecidas falham fechado.
- Erros internos do Supabase são substituídos por mensagens técnicas seguras.
- Agregados financeiro/dashboard exigem implementação injetada; ausência bloqueia a leitura.

## Correção de compatibilidade

O contrato M18 mencionava `erp_stock_balance_v`, mas essa view não existe nas migrations versionadas. O adaptador não inventa dependência remota: consulta `erp_stock_movement_items` e agrega `quantity_delta` por tenant, local, item e variante.

## Evidências

- Adaptador com dublês: 17/17 testes.
- Contrato visual: 49/49 testes.
- Plataforma: 74/74 testes.
- TypeScript e ESLint da plataforma: aprovados.
- Build Next.js com Node.js 22: aprovado.
- Nenhuma tela foi conectada ao adaptador neste gate.
- Nenhuma rede, credencial, Supabase remoto ou produção foi acessada.

Marcador: `M18_G6_SUPABASE_ADAPTER_LOCAL_OK`

Próximo gate: M18-G7 — implementar agregados tenant-scoped e composição server-side do cliente persistente, ainda com dublês e sem ativar o transporte remoto nas telas.
