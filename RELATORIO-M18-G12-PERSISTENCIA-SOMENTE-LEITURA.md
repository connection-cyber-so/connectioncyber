# M18-G12 — persistência visual somente leitura

Data: 01/09/2026

Estado: aprovado localmente e validado remotamente em staging

Marcador: `M18_G12_PERSISTENT_READ_ONLY_OK`

## Resultado

- Feature flag privada `SERVER_VISUAL_PERSISTENCE_MODE` aceita somente `synthetic` ou `persistent-read-only`.
- Modo persistente de escrita e valores desconhecidos falham fechado.
- Leituras persistentes usam sessão e tenant derivados no servidor.
- Todos os comandos e preparações de venda/baixa são bloqueados antes de criar o cliente persistente.
- Telas continuam compatíveis com o dublê sintético por padrão.

## Validação remota

- Supabase staging vinculado com migrations `0001–0033` sincronizadas.
- Consulta executada dentro de `BEGIN TRANSACTION READ ONLY` e encerrada com `ROLLBACK`.
- Sete RPCs versionadas presentes e RLS ativa nas oito relações críticas verificadas.
- Tenant sintético `00000000-0000-4000-8000-000000000018` ausente.
- Zero command receipts para o tenant sintético.
- Nenhuma RPC, migration ou escrita executada.

## Evidências

- Plataforma: `93/93` testes.
- Contrato: `50/50` testes.
- Adaptador: `44/44` testes.
- TypeScript, ESLint e build Next.js: aprovados.

O próximo gate é a preparação protegida do tenant e do usuário-piloto Mania de Modas. Esse gate altera o staging e permanece separado.
