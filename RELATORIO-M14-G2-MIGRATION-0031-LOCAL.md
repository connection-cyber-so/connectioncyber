# M14-G2 — migration local 0031

Data: 29/08/2026
Ambiente: staging local
Decisão: **ARTEFATOS APROVADOS; EXECUÇÃO POSTGRESQL LOCAL PENDENTE**

## Entrega

- migration `0031_m14_import_ledger.sql`;
- sete tabelas tenant-scoped;
- cinco RPCs exclusivamente `service_role`;
- RLS e leitura autenticada por permissões;
- preflight, rollback e 80 asserções pgTAP;
- testes estáticos do pacote de importação.

## Controles

- nenhum backup, caminho, credencial ou payload bruto no ledger;
- hashes SHA-256 para origem, mapeamento, lote, item e evidência;
- conflito de idempotência em manifesto, job, lote e item é fail-closed;
- reconciliação de quantidade e centavos sob bloqueio de linha;
- escrita direta por `authenticated` e acesso de `anon` revogados;
- produção e Supabase remoto não acessados.

## Evidências executadas

- testes Node/estáticos: `37/37`;
- simulador: `M14_G1_IMPORT_SIMULATOR_OK`;
- `git diff --check`: aprovado;
- migration aplicada: `false`;
- dados criados: `false`.

## Bloqueio local

O Docker Desktop iniciou seus processos, mas o daemon não respondeu e a distribuição `docker-desktop` permaneceu indisponível para a CLI. Por segurança, os testes pgTAP não foram redirecionados ao Supabase remoto.

## Próxima ação

Inicializar o Docker Desktop até o Engine indicar execução ativa. Depois executar preflight, migration, 80 pgTAP, rollback, verificação de zero resíduos, reconstrução e nova passagem 80/80 somente no banco local descartável.
