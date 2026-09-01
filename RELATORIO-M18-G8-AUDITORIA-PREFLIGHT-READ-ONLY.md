# M18-G8 — auditoria final local e preflight remoto somente leitura

Data: 01/09/2026

## Resultado da auditoria

1. **UUID de tenant permissivo:** remediado com validação estrutural de UUID RFC 4122 antes de consulta ou RPC.
2. **Histórico de caixa dependia do texto de interface:** remediado com chave canônica obrigatória em cada read model.
3. **Formatos persistentes ainda diferem dos modelos visuais locais:** permanece bloqueado para ativação das telas. O futuro ensaio somente leitura valida infraestrutura, não constitui aceite visual persistente.

## Preflight preparado

Arquivo: `supabase/preflight/m18_g8_visual_read_only_preflight.sql`.

- inicia transação com `SET TRANSACTION READ ONLY`;
- verifica sete RPCs, relações, colunas, RLS e privilégios;
- compara `authenticated` com `anon`;
- emite `M18_G8_READ_ONLY_PREFLIGHT_OK`;
- termina obrigatoriamente com `ROLLBACK`;
- não contém comandos SQL mutáveis.

## Evidências locais

- Adaptador, agregados e preflight: 31/31 testes.
- Contrato visual: 50/50 testes.
- Plataforma: 80/80 testes.
- TypeScript, ESLint e build Next.js com Node.js 22: aprovados.
- Supabase remoto não acessado; nenhuma conta, sessão, receipt ou dado criado.

## Parecer

Pronto exclusivamente para preflight remoto somente leitura no staging `ozvylnaipubrmaadikvk`, após autorização específica. Não está autorizado conectar as telas, executar RPC de comando, criar fixtures ou acessar produção.

Marcador local: `M18_G8_LOCAL_AUDIT_READ_ONLY_PREFLIGHT_READY`

Próximo portão: M18-G9 — executar exclusivamente o preflight remoto somente leitura e exigir `M18_G8_READ_ONLY_PREFLIGHT_OK`.
