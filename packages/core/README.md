# packages/core — regras de negócio compartilhadas (ainda não iniciado)

Lógica de domínio comum a todos os tenants do ConnectionCyberSO — o que muda
de cliente para cliente é configuração (`tenant_settings`, feature flags,
módulo por vertical), não código duplicado. Ver `Parecer técnico #001`,
seção 06, para o mapeamento completo de "particularidade de cliente → como
isso vira configuração aqui".

Candidatos ao que entra aqui, quando `apps/platform` começar a ser
construído:
- Cadastro de cliente / fornecedor / funcionário
- Rotinas fiscais compartilhadas
- Validações e tipos comuns entre `apps/platform` e `apps/site`
