# RELATÓRIO M15-G13 — Catálogo/estoque reais + conferência de domínio/deploy

Data: 29/09/2026
Executável: `scripts/m15-stock-bootstrap.mjs` (idempotente, SQL em `%TEMP%\connectioncyber-m15\`).
Ambiente: Supabase staging `ozvylnaipubrmaadikvk`.

## 1. Estoque por tenant

| Entidade | Resultado |
|---|---|
| `erp_stock_locations` | **6 locais ativos** (1 por estabelecimento) em **5 tenants** — Rose, Casa de Bolos, CSC, Loja da Benção e Mania de Modas |
| `erp_catalog_items.track_inventory` | **872 produtos** agora rastreando estoque (antes 0) |
| Saldo inicial | **0 — não inventado** |

Decisão: o saldo real de abertura exige **contagem física** na loja (operação real, ligada à
jornada do M15-G15). Gerar quantidade sem fonte seria dado falso e violaria o critério de
aceite "counts and amounts reconcile". O livro `erp_stock_movements` está pronto para a
movimentação de entrada do inventário inicial, com `allows_negative=false` por local.

Idempotência: id local = `uuidFromSha256(tenant|estabelecimento|stock-location)`;
re-execução não duplica. Validação embutida: locais conferidos contra a lista de
estabelecimentos ativos (`M15_STOCK_SUMMARY`).

## 2. Conferência de domínio/deploy (achado: **bloqueio para corte**)

Levantamento de rede em 29/09/2026:

| Domínio | Registros A | HTTPS | HTTP |
|---|---|---|---|
| `connectioncyber.com.br` (raiz) | `76.76.21.21` | **200** ✓ | 308 (redireciona) |
| `rosevariedades.…` | `76.76.21.123` **+** `66.33.60.35` | falha TLS (handshake) | 404 |
| `casadebolosaconchego.…` | `76.76.21.142` **+** `66.33.60.66` | falha TLS | 404 |
| `cscdistribuidora.…` | `66.33.60.130` **+** `76.76.21.61` | falha TLS | 404 |
| `maniademodas.…` | `76.76.21.93` **+** `66.33.60.194` | falha TLS | 404 |
| `lojadabencao.…` | `76.76.21.241` **+** `66.33.60.193` | falha TLS | 404 |

Achados:

1. **Cada subdomínio tem dois registros A**: um alvo Vercel (`76.76.21.x`) e um alvo
   desconhecido `66.33.60.x` — round-robin faz metade das requisições cair num host que não
   atende TLS. Isso também explica a divergência registrada no parecer M15-G0 (alvos pareciam
   trocados entre o parecer e agora: a consulta alterna entre os dois conjuntos).
2. **TLS falha mesmo forçando o alvo Vercel** (`curl --resolve`): o subdomínio não está
   configurado no projeto Vercel (sem certificado emitido). Só a raiz tem cert ativo.
3. O provedor `66.33.60.x` responde 404 em HTTP e não completa handshake TLS.

Correção necessária (**exige painel externo — não executada aqui**):

1. No provedor DNS: remover os registros `66.33.60.*` dos cinco subdomínios (manter só os
   `76.76.21.*` do Vercel).
2. No painel Vercel do projeto correspondente: adicionar os cinco subdomínios
   (`rosevariedades`, `casadebolosaconchego`, `cscdistribuidora`, `maniademodas`,
   `lojadabencao` + `.connectioncyber.com.br`) e aguardar a emissão do certificado.
3. Revalidar: `https://<subdominio>` → 200/307 e cert válido nos cinco.

Enquanto isso não for feito, **M15-G15 (jornada real) e M15-G18 (corte) ficam bloqueados**.

## 3. Próxima ação

**M15-G14** — identidades Auth + convite + MFA dos responsáveis. Portão **requer autorização**
(criar usuários reais); nenhum passo foi executado.
