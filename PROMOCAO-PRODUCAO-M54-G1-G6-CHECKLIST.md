# Checklist de promoção para produção — M54-G1 a G6

Status: **NÃO EXECUTADO.** Projeto de produção: `connectioncyber` (`qfggetvashdxyuvlhihq`).
Regra: nada aqui roda sem autorização explícita e registrada do responsável ("pode produção").
Staging de referência: `ozvylnaipubrmaadikvk` (todos os gates validados, commits até `f651039` e `6910d27`; G6 pendente de commit).

## 0. Bloqueios que impedem promover hoje
1. **Pré-requisito 0053 e 0054 em produção.** 0056 e 0058 dependem do tenant Nuvem (`00000000-0000-0000-0000-000000000001`), criado pela 0054. Produção ainda não tem essas migrations. Promover 0053 e 0054 exige portão próprio (CNPJ real, custódia do A1, DNS do domínio).
2. **Catálogo de produtos inexistente.** `saldos.produto_id`, `pedidos_cd_itens.produto_id`, `transferencia_itens.produto_id` e `reservas.produto_id` estão sem FK. Decidir se o catálogo entra antes ou se a FK fica para depois.
3. **Dados de produção não validados.** Os ensaios usaram dado 100% FICTICIO. Não há validação com dado real do cliente.
4. **Camada de interface não existe.** As RPCs da 0060 estão prontas; a tela que as chama não.

## 1. Ordem de migrations (nunca fora de ordem)
| Ordem | Migration | Depende de | Commit staging |
|---|---|---|---|
| 1 | 0053_tenant_domains | — | `e43df55` |
| 2 | 0054_tenant_nuvem_de_papel | 0053 | `0dbde2c` |
| 3 | 0055_cd_locais_enderecos_saldos | 0054 | `68a7389` |
| 4 | 0056_cd_planos_capacidades | 0055, catálogo de capacidades | `ca93a35` |
| 5 | 0057_cd_pedidos_transferencias | 0055 | `b36fb35` |
| 6 | 0058_cd_alocacao_pedido | 0056, 0057 | `cbb6184` |
| 7 | 0059_cd_recebimento_coleta_despacho | 0058 | `6910d27` |
| 8 | 0060_cd_api_rpc | 0059 | a commitar |

## 2. Antes de qualquer comando em produção
- [ ] Autorização explícita e registrada (mensagem com "pode produção" e a lista de migrations).
- [ ] Backup lógico completo do projeto de produção, com hash SHA-256 e teste de restauração em cópia isolada.
- [ ] Janela de deploy combinada, com rollback disponível.
- [ ] Histórico de migrations de produção conferido (`0001…última` aplicada, sem lacuna).
- [ ] Commit do staging em `origin/staging` e tag do estado promovido.

## 3. Por migration (repetir para cada uma, em ordem)
1. **Preflight somente leitura** (arquivo em `supabase/preflight/`). Esperado: zero conflito, dependências presentes.
2. **Ensaio transacional** (migration + teste dentro de `begin … rollback`). Esperado: sem `FALHOU`, zero resíduo depois.
3. **Aplicar** com `apply_migration` ou `db push`, somente a migration da vez.
4. **Verificação pós-apply:** tabelas com RLS, policies, funções `security definer`, grants (`anon` sem acesso), contagens esperadas.
5. **Teste oficial** (arquivo em `supabase/tests/`) executado em transação com rollback.
6. **Registro:** entrada no `STATUS-MESTRE-DESENVOLVIMENTO.md` (.md e .html) com hash e evidência.
7. Se algo falhar: **parar**, não avançar. Correção por forward-fix (nova migration). Rollback só com tabelas vazias (arquivos em `supabase/rollback/`).

## 4. Dados e configuração de produção
- [ ] Nenhum dado FICTICIO vai para produção. Os testes usam transação com rollback.
- [ ] Configuração padrão (`cd_configuracoes`, `regras_saida`) é inserida só para tenants reais já autorizados.
- [ ] Capacidades `cd.armazenagem`, `cd.expedicao`, `site.loja` concedidas por tenant, com `evidence_hash` do contrato.
- [ ] Papéis e permissões (`stock.manage`, `sales.order`) conferidos por tenant antes de liberar a API.

## 5. Após promover (critérios de aceite)
- [ ] RPCs `cd_api_*` respondem: sem autenticação falha (42501), sem permissão falha, com capacidade suspensa falha.
- [ ] Pedido acima de 50 un. ou R$ 2.000 fica `aguardando_aprovacao` sem reservar.
- [ ] Falta no CD gera transferência loja → CD ligada ao pedido.
- [ ] Recebimento, coleta e despacho dão baixa conforme a regra (CD na coleta; loja no despacho).
- [ ] Anon sem acesso às tabelas e RPCs do CD.
- [ ] Logs de erro do Supabase sem novos alertas nas primeiras 24 horas.

## 6. Rollback (se algo der errado depois de promover)
- Forward-fix é o padrão. Rollback destrutivo só em ambiente sem dado real.
- Ordem reversa: 0060 → 0059 → … (cada rollback aborta se houver movimentação).
- Após qualquer rollback, registrar o motivo e reabrir o gate.

## 7. Pendências que continuam fora deste checklist
- `produto_id` sem FK (decisão do catálogo).
- Domínio `nuvemdepapel.com.br` está `pendente`.
- CNPJ e emitente reais da Nuvem (autorização separada).
- Custódia do A1, migração A3 → A1 e cutover fiscal (portões próprios).
- Dependências do app: Next 14.2.35 e node-forge; `npm audit` do `apps/portal` e `apps/platform`.
