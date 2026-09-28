# Parecer Técnico M24-G0 — Envio fiscal mensal ao contador (substitui o AnyDesk)

**Data:** 28/09/2026
**Módulo:** M24 — Envio ao contador
**Ambiente:** staging (`ozvylnaipubrmaadikvk`)
**Status:** aprovado para implementação e já executado (ver `RELATORIO-M24-G0-ENTREGA-LOCAL.md`)

## 1. Contexto e objetivo

Hoje o escritório contabil recebe os XMLs de cada cliente por **AnyDesk**, um acesso por vez,
sem trilha de auditoria, sem confirmação de recebimento e sem isolamento entre empresas. O
objetivo declarado pelo responsável é tornar o sistema o canal oficial desse envio mensal,
como parte da proposta de SaaS multi-tenant por assinatura: cada cliente acessa a plataforma
com credenciais próprias, publica a competência do mês e o contador confere e registra o
recibo dentro do próprio portal.

## 2. Decisão

Implementar o **pacote fiscal mensal** com estas regras:

1. O **dono/staff do tenant** publica um pacote por competência (mês), contendo de 1 a 500
   arquivos `.xml` (NF-e/NFC-e) e `.pdf` (DANFE), com:
   - caminho canônico `{tenant_id}/{YYYY-MM}/{arquivo}`;
   - SHA-256 de cada arquivo calculado **no servidor**;
   - **manifesto** do pacote = SHA-256 do conjunto ordenado de `hash arquivo` (não depende da
     ordem do cliente e é verificável manualmente pelo contador);
   - idempotência por chave estável `pub:{tenant}:{competencia}` — republicar a mesma
     competência não duplica nem sobrescreve pacote confirmado.
2. O **contador** (papel `contador`) enxerga os pacotes de **todos** os tenants, mas
   **exclusivamente pela RPC auditada** `erp_list_accountant_packages` — sem policy de select
   direto. Cada listagem, baixa e recibo gravam linha em `logs_access`.
3. Estados: `ready` (aguardando recibo) → `acknowledged` (recibo do contador) ou `void`
   (anulado pelo dono, com motivo obrigatório). Pacote `void` não recebe recibo; recibo e
   anulação são idempotentes por chave estável.
4. Bucket privado `fiscal-deliveries` (10 MB por arquivo) com 5 policies próprias
   (`fd_storage_*`): escrita apenas sob o prefixo do próprio tenant, leitura pelo dono ou
   pelo papel contador, nenhuma leitura pública.

## 3. Por que este desenho

- **Zero trilha fora do sistema:** o recibo substitui a "confirmação por conversa" do
  AnyDesk; a auditoria em `logs_access` substitui o acesso remoto sem registro.
- **Fail-closed:** permissão `fiscal.deliver` exigida por membership ativa + papel ativo;
  o papel contador só lê via RPC `security definer`; competência futura ou dia ≠ 1 recusada;
  validação de extensão **e** de conteúdo (`<` para XML, `%PDF` para PDF) no upload.
- **Manifesto verificável:** o contador pode conferir lote desordenado sem confiar na ordem
  de envio — mesma técnica do importador M14.
- **Nenhum objeto pré-existente foi modificado** além de um insert em `public.roles` e um
  insert em `public.erp_permissions` — o risco de regressão é baixo (regressão 0049 coberta).

## 4. Riscos residuais e decisões conscientes

| Risco | Mitigação/decisão |
|---|---|
| Upload interrompido deixa arquivo órfão no bucket | Readable apenas pelo dono/contador; próxima tentativa de mesmo nome falha como "already exists" e é tratada; pacote não é publicado sem passar pela RPC |
| Recibo sem conferência real | Recibo é registro de responsabilidade do contador; nota opcional de até 2000 caracteres |
| Contador vê clientes de outros tenants | É o requisito do negócio (escritório contabil); toda leitura é auditada em `logs_access(user_id, rota, tenant_id)` |
| Pacote anulado voltar a contar como entregue | Estado `void` é terminal; novo envio = nova publicação da competência após un-void? Não: anulação exige re-publicação consciente (chave idempotente por competência impede republicação silenciosa) |

## 5. Critérios de aceite (todos cumpridos em staging)

1. Migration `0050_m24_accountant_delivery` aplicada exclusivamente em staging (histórico
   0001–0050), com preflight, validação transacional **61/61 com ROLLBACK** e resíduo zero.
2. Testes pgTAP **36/36** (estrutural) e **25/25** (adversarial: cross-tenant, RLS, idem,
   void, nome malicioso, conteúdo divergente) remotos.
3. Regressão M23: **12/12 + 24/24**; REST anônimo 200 sem `42501`.
4. Portal: rota `/fiscal/contador` com publicação (upload + RPC), recibo e anulação;
   `lint`, `tsc` e **155/155** testes Node verdes.
5. Produção intocada.

## 6. Portão seguinte

M25 (assinatura MP + auto-provisionamento) → R-003 (backup/RPO-RTO) → M14 lote real
(4.225 XMLs em `C:\Users\joaqu\Downloads\SICNETNFS`), nesta ordem, conforme autorização do
responsável em 28/09/2026.
