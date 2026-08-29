# M14-G1 — contrato canônico e simulador de importação

Data: 29/08/2026
Ambiente: staging local
Decisão: **APROVADO COM DADOS EXCLUSIVAMENTE SINTÉTICOS**

## Entrega

- pacote independente `@connectioncyber/import-contract`;
- manifesto imutável com SHA-256 da origem;
- lote canônico vinculado ao manifesto e ao tenant;
- dez domínios: clientes, fornecedores, funcionários, produtos, estoque, vendas, caixa, receber, pagar e metadados fiscais;
- simulador em memória com replay idempotente e relatório sem payload.

## Invariantes comprovadas

1. origem mutável, caminho físico, credencial ou dado real são recusados;
2. tenant divergente é bloqueado inclusive em objetos aninhados;
3. quantidade e valor são reconciliados antes da carga;
4. conflito impede o lote inteiro, sem aplicação parcial;
5. reexecução preserva um único registro e o mesmo relatório.

## Evidências

- testes: `24/24`;
- marcador: `M14_G1_IMPORT_SIMULATOR_OK`;
- fonte real aberta: `false`;
- persistência, Supabase remoto e produção: `false`.

## Próxima etapa

M14-G2: migration local `0031` para manifestos, jobs, lotes, itens, rejeições e reconciliações com RLS. Preflight, rollback e pgTAP devem ser preparados antes de qualquer validação remota.
