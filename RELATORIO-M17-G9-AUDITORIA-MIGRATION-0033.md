# M17-G9 — auditoria técnica independente da migration 0033

Data: 31/08/2026

Escopo: exclusivamente local em staging

Resultado: aprovada localmente após remediação

## Bloqueios encontrados e corrigidos

1. O hash canônico do cliente JavaScript não era compatível com a serialização `jsonb::text` do PostgreSQL. O banco passou a calcular e persistir seu próprio SHA-256 autoritativo.
2. `digest` não estava qualificada sob `search_path` vazio. A chamada agora usa `extensions.digest`, confirmada diretamente no staging pelo preflight M17-G10.
3. O payload não tinha limite de tamanho nem triagem de chaves de segredo. O claim agora recusa mais de 64 KiB e nomes de campos sensíveis.
4. Recebimento de estoque não confirmava item rastreável ativo e local ativo do mesmo tenant. As duas relações agora são verificadas antes do efeito.
5. A conclusão de venda não materializava o recebível prometido pelo contrato M17-PG-1.0. Crediário integral da loja agora cria título e parcela na mesma transação; cliente, valor e identidade vêm do banco, e modalidade mista falha fechada.

## Evidências

- 168/168 testes do pacote aprovados.
- 32/32 testes da plataforma aprovados.
- Simulador do contrato PostgreSQL aprovado.
- ESLint e TypeScript aprovados.
- `git diff --check` aprovado.
- Plano pgTAP ampliado de 90 para 96 asserções; execução em PostgreSQL/remoto continua pendente e bloqueada.
- SHA-256 final após confirmação do schema `extensions` no M17-G10: `f20d6f908a7f8477e5a6dd96cc02b2634451943b9bac70839ba4aa686e848e26`.

## Limites preservados

- Nenhum acesso ao Supabase, Vercel, GitHub ou produção.
- Nenhuma migration aplicada persistentemente.
- Nenhuma conta ou dado real criado.
- Alterações não relacionadas da árvore de trabalho foram preservadas.

Marcador: `M17_G9_MIGRATION_0033_LOCAL_AUDIT_OK`.

Próximo portão: preflight remoto e validação transacional da `0033` com `ROLLBACK`, 96 asserções e autorização específica.
