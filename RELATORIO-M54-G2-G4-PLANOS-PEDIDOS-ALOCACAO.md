# RELATÓRIO M54-G2 a G4 — planos, pedidos do CD e alocação ponta a ponta

Data: 06/11/2026 · Ambiente: staging `ozvylnaipubrmaadikvk` · Produção: intocada

## M54-G2 — planos e capacidades (0056, commit ca93a35)
- Catálogo: `cd.armazenagem`, `cd.expedicao`, `site.loja`.
- Dependências em `erp_capability_dependencies`: `cd.armazenagem → inventory.stock`; `cd.expedicao → cd.armazenagem`; `site.loja → sales.pos` e `inventory.stock`.
- Trigger `trg_erp_tenant_capabilities_deps`: fail-closed. Ativar ou pôr em trial exige dependência ativa no mesmo tenant.
- Nuvem de Papel: 3 capacidades `active`, evidence_hash SHA-256.
- Evidência: ensaio transacional no staging com 6 checagens (suspender armazenagem bloqueia expedição); aplicação; pós-apply 3/3/3, RLS e trigger ativos.

## M54-G3 — pedidos, transferências e reservas (0057, commit b36fb35)
- Tabelas: `cd_configuracoes`, `regras_saida`, `pedidos_cd`, `pedidos_cd_itens`, `transferencias`, `transferencia_itens`, `reservas`.
- Tipo de local: pedido só sai de local `cd`; transferência só vai de `loja` para `cd`.
- Defaults: 50 un. ou R$ 2.000; política de falta `transferencia_automatica`.
- Evidência: ensaio transacional (pedido em loja falha, coleta sem autorização falha, reserva com qtd 0 falha, canal inválido falha, defaults 50/2000); aplicação; pós-apply com RLS e 1 policy em cada tabela.

## M54-G4 — alocação ponta a ponta (0058, commit a registrar)
- Função `public.cd_alocar_pedido(tenant, pedido, aprovado)`: `security definer`, `search_path=''`, execute só para `service_role`.
- Regras: acima do limite sem aprovação não reserva nada (`aguardando_aprovacao`); com CD no canal, reserva no CD primeiro; falta no CD vira reserva na loja + transferência loja → CD ligada ao pedido; canal sem CD (balcão, shopee) reserva direto na loja.
- Config da Nuvem: `cd_configuracoes` (50 / 2000 / transferencia_automatica) e 4 regras de saída (web: cd → loja; balcão e shopee: loja).
- Dado 100% FICTICIO (produto `33333333-…`, locais `FICTICIO-*-G4`), dentro do teste com ROLLBACK:
  - CD 45, loja 55, pedido web 60 un. a R$ 15,00 → `aguardando_aprovacao`, zero reservas;
  - com aprovação: CD reserva 45, transferência loja → CD de 15, falta 0;
  - segunda alocação do mesmo pedido é recusada;
  - balcão de 10 un. reserva direto na loja;
  - saldos finais: loja reservada 25, disponível total 30.
- Evidência: ensaio transacional 5/5 no staging; aplicação; pós-apply função definer, config e 4 regras, zero resíduo de teste.

## Pendências (não bloqueiam o fechamento)
1. `produto_id` sem FK até o catálogo de produtos existir.
2. Recebimento da transferência, coleta, despacho e baixa: fases seguintes (não estão no M54-G4).
3. A função não tem camada de API: a chamada via RPC pública fica para o gate da interface.
4. Produção: nada foi aplicado; exige autorização separada.
