# M18-G0 — contrato da integração visual persistente

Data: 31/08/2026

Resultado: aprovado localmente.

## Contrato

- Versão: `M18-VISUAL-1.0`.
- Comandos persistentes: 7.
- Read models tenant-scoped: 11.
- Estados UX: 7 (`idle`, `validating`, `submitting`, `revalidating`, `succeeded`, `failed`, `blocked`).
- Ameaças modeladas: 10.

## Mapa visual

| Tela | Comando | RPC | Releitura obrigatória |
|---|---|---|---|
| `/cadastros` | `party.create` | `erp_command_create_party_v1` | clientes |
| `/catalogo` | `catalog.item.create` | `erp_command_create_catalog_item_v1` | catálogo |
| `/operacoes` | `inventory.receive` | `erp_command_receive_inventory_v1` | saldo e movimentos |
| `/pdv` | `cash.open` | `erp_command_open_cash_v1` | caixas abertos |
| `/pdv` | `sale.complete` | `erp_command_complete_sale_v1` | vendas, estoque, caixa e financeiro |
| `/financeiro` | `finance.receivable.settle` | `erp_command_settle_receivable_v1` | títulos, parcelas e resumo |
| `/pdv` | `cash.close` | `erp_command_close_cash_v1` | caixas, histórico e dashboard |

## Controles fixados

1. Navegador não envia tenant, ator, permissão, capacidade, papel, preço, saldo ou total autoritativo.
2. Campos de segredo são recusados recursivamente e payloads acima de 64 KiB falham fechado.
3. Sucesso visual só ocorre depois da releitura do banco; estado otimista não é autoridade.
4. Submissão não é reentrante e escrita não recebe retry automático cego.
5. Erros SQL e detalhes internos são convertidos em códigos e mensagens públicas estáveis.
6. Cada comando define read models exatos para revalidação.

## Evidências

- 30/30 testes do contrato aprovados com Node.js 22.23.2.
- Simulador: `M18_G0_VISUAL_PERSISTENCE_CONTRACT_OK`.
- 32/32 testes da plataforma aprovados.
- TypeScript e ESLint aprovados.
- `git diff --check` aprovado.
- Varredura de identificadores empresariais e credenciais reais: limpa.
- Banco, Supabase, Vercel, GitHub remoto e produção não acessados.

Marcador: `M18_G0_VISUAL_PERSISTENCE_CONTRACT_OK`.

Próxima etapa automática: **M18-G1 — cliente server-side tipado para as sete RPCs e read models tenant-scoped, usando dublês locais e sem acesso remoto.**
