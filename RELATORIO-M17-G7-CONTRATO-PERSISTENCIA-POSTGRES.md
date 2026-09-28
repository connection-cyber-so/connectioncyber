# M17-G7 — contrato de persistência PostgreSQL/Supabase

Data: 31/08/2026

## Resultado

Foi definido o contrato `M17-PG-1.0` para persistir os sete comandos da jornada integrada. O desenho reutiliza as migrations `0021`, `0022`, `0023`, `0024` e `0032`, sem alterar ou duplicar a baseline.

## Fronteira transacional

- sete RPCs versionadas, uma para cada comando;
- cada RPC executa em uma única transação PostgreSQL;
- host, tenant, ator, membership, permissão e capacidade são resolvidos antes da escrita;
- `erp_command_receipts` será o inbox planejado, único por tenant, comando e request;
- replay exige o mesmo SHA-256; hash divergente falha fechado;
- preços, totais, estoque, caixa e financeiro são derivados no servidor;
- erro reverte receipt e todas as escritas do domínio.

## Concorrência

- receipt é bloqueado primeiro;
- locks de estoque e parcelas são ordenados deterministicamente;
- caixa e agregados mutáveis exigem lock ou versão otimista;
- SQLSTATE `40001` e `40P01` aceitam no máximo duas repetições no servidor;
- navegador nunca repete escrita automaticamente.

## Segurança e isolamento

- todas as tabelas do contrato são tenant-scoped e protegidas por RLS;
- FKs entre domínios incluem `tenant_id`;
- escrita direta por `authenticated` é proibida; comandos passam por RPC;
- RPCs usam `SECURITY DEFINER`, `search_path` vazio e nomes qualificados;
- `service_role` nunca chega ao navegador;
- auditoria não guarda payload, segredo ou detalhe SQL.

## Evidências

- 141/141 testes do pacote aprovados com Node.js 22.23.2.
- 25 asserções específicas do contrato aprovadas.
- Plataforma: 32/32 testes, TypeScript, ESLint e build aprovados.
- Validador: `M17_G7_POSTGRES_PERSISTENCE_CONTRACT_OK`.
- Sete RPCs, sete grupos de tabelas, 20 invariantes e oito gates de promoção.
- Nenhuma migration criada; Supabase, rede e produção não acessados.

## Parecer

Contrato aprovado para materialização local em uma migration futura. A implementação SQL ainda deverá passar por auditoria independente, preflight, validação com `ROLLBACK`, pgTAP concorrente e autorização específica antes de qualquer aplicação persistente.

Marcador: `M17_G7_POSTGRES_PERSISTENCE_CONTRACT_OK`

Próxima etapa automática: M17-G8 — migration local `0033`, inbox transacional, RPCs versionadas, RLS, preflight, rollback e testes pgTAP; sem aplicação remota.
