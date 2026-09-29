# RELATÓRIO M14-G9 — carga real do lote SICNET no ledger de importação

Atualização: 29/09/2026. Estado: **concluído no Supabase staging `ozvylnaipubrmaadikvk`** — 3 tenants carregados, 14/14 lotes reconciliados (`balanced`), 0 bloqueados, produção intocada.

## 1. Decisão e escopo

Sequência autorizada pelo usuário ("M24 → M25 → R-003 → M14 lote real, de ponta a ponta sem intervenção"), modalidade **A escolhida pelo usuário**: provisionar 2 tenants novos no staging (Rose Variedades, CSC Distribuidora) e importar os 3 emitentes completos de `C:\Users\joaqu\Downloads\SICNETNFS`. Corte/comercial (identidades Auth, catálogo, jornada de venda) fica para o **M15**; materialização de entidades (`erp_people`, `erp_sales`, …) também — nesta etapa o **ledger de importação** (0031+0052) recebeu manifesto, job, lotes, itens e reconciliação.

## 2. Levantamento da fonte (4.225 XMLs, classificação por conteúdo)

| Classe | Qtde | Tratamento |
|---|---:|---|
| `nfeProc` — NFes autorizadas (mod 65, NFC-e) | **1.567** | importadas |
| `AntesDeValidar` / `<NFe>` sem protocolo (rascunho) | 102 | descartadas (não autorizadas) |
| `CFe` de SAT (mod 59, 2025) | 2.547 | fora do escopo NF-e |
| `consSitNFe`/`retConsSitNFe` (consultas SEFAZ) | 9 | artefato de consulta, não documento |

16 pastas de emitentes; só 3 têm XML fiscal (demais = MEIs/docs/PDF). Classificador em `packages/import-contract/src/nfe-adapter.mjs` decide pelo **conteúdo do XML**, não pelo nome do arquivo.

## 3. Provisionamento e mapeamento

| Tenant | slug | XMLs autorizados | NFes únicas importadas | Registros | Lotes | Valor declarado (== aplicado) |
|---|---|---:|---:|---:|---:|---:|
| Rose Variedades | `rosevariedades` | 1.455 | 1.455 | 3.703 | 6 | R$ 38.730,07 |
| Casa de Bolos Aconchego | `casadebolosaconchego` | 100 | 50 | 175 | 4 | R$ 11.055,00 |
| CSC Distribuidora | `cscdistribuidora` | 12 | 6 | 22 | 4 | R$ 147,61 |
| **Total** | | **1.567** | **1.511** | **3.900** | **14** | **R$ 49.932,68** |

56 dos 1.567 XMLs autorizados são cópias repetidas em pastas distintas (mesma chave de
acesso) — deduplicadas por chave; a carga não duplica nota.

Registros por domínio: `sales` (1 por NF-e), `fiscal-metadata` (1 por NF-e), `products` e `customers` deduplicados. Cada XML é validado contra o CNPJ do estabelecimento do tenant antes de entrar (`expectedCnpj` no config) — fonte↔tenant verificado, não apenas acreditado.

## 4. Migration 0052 (gate completo em staging)

`0052_m14_nfe_xml_source.sql` estende o check de `source_type` de `erp_import_manifests` com `nfe_xml` e recria `erp_register_import_manifest` com o valor no allowlist.

- Preflight `M14_0052_PREFLIGHT_OK` + transação `0052_transaction.generated.sql` com **16/16 pgTAP ROLLBACK** + resíduo zero;
- `run-0052-remote.ps1`: dry-run selecionou **somente** a 0052; `db push` aplicou (histórico `0001.0052`);
- Pós-apply `M14_0052_POST_APPLY_OK`; **16/16** + regressões **96/96** (0031) + **38/38** + **28/28** (0051) remotos; preflight passou a recusar (`ja aplicada`); REST anônimo 200 sem 42501.

Hashes SHA-256: migração `FACB848B63080A8C…FDABA3E`; transação `14AA81A034D24590…FBBD5E`; builder `D272C408505B3E8E…751B88B`. Logs em `staging/logs/m14-0052-remote-20260929-*.log`.

## 5. Pipeline de carga (sem dado real no repo)

1. **Contrato v1.1** (`packages/import-contract`): fonte `nfe-xml` aceita; `containsRealData` obrigatório (booleano) em v1.1; **v1.0 intacta** (dado real continua bloqueado lá). 60/60 testes.
2. **Adaptador** (`src/nfe-adapter.mjs`): classificação, parse de NF-e (regex determinístico, sem dependências), `planImport` → lotes canônicos ≤1000 ordenados e com `batchId` derivado de hash (replay idempotente). Valor financeiro mora **só** em `sales`; `fiscal-metadata`/`customers`/`products` entram com `amountCents = 0`.
3. **Orquestrador** (`scripts/m14-import-nfe.mjs`): varre a fonte, hash indexado por arquivo (`sourceSha256`), `capturedAt` = maior mtime, manifesto determinístico, gera SQL com as RPCs `service_role` (claims via `set_config`), executa `supabase db query --linked -f`, lê o marcador `M14_LOAD_SUMMARY` e exige manifesto `validated`, job `completed`, `reconciliados == lotes`, `bloqueados = 0`.
4. **Reconciliação**: `erp_finalize_import_batch` grava `erp_import_reconciliations` (`balanced` gerado); verificação **independente** no banco por query fora da transação.

SQL e config gerados ficam **só** em `%TEMP%\connectioncyber-m14\` (fora do Git), no padrão M21-G7. O ledger guarda apenas `canonical_key` (hash para clientes), `source_key_hash`, `payload_hash` e métricas — **payload bruto e CPF/CNPJ nunca vão ao banco**; chave de cliente é `sha256(document)`.

## 6. Achados

1. **SQL sem `commit;`**: o primeiro SQL gerado abria `begin;` e não fechava — o `DO block` e o resumo interno "provavam" a carga dentro da transação, mas a sessão encerrava em rollback (0 linhas; a query independente mostrou `total_manifestos = 0`). Corrigido com commit explícito e re-executado. Lição registrada: prova de carga exige commit + verificação fora da transação.
2. **CFe/SAT**: 2.547 dos "desconhecidos" eram cupons SAT de 2025 — ganharam classe própria (`sat-coupon`) para o relatório refletir a realidade.
3. **`-f` da CLI**: executam todos os statements e devolvem só o último result set com linhas (por isso o resumo é o SELECT final, após o `DO`).

## 7. Inventário do acervo (R-008)

6 backups SQL Server (41–198 MB) inventariados com SHA-256, todos fora do Git:

| Arquivo | MB | SHA-256 |
|---|---:|---|
| backup 1 | 197,2 | `458679e11e0ac30c98b08dbb23c8960235299c41387e24f870e0e412d71b98e7` |
| backup 2 | 198,2 | `4cb14f015c56079693c6972bd30190d020f25693f41e7945e026580b05b080bc` |
| backup 3 | 41,2 | `7aa896e54f60298067a863ce81d8cde855dfc049eda5239046dc778de438d7a5` |
| backup 4 | 41,0 | `67321d022eebdcf8b52bee085c818422a1dfb635296e9cd2c8b99093b01badaf` |
| backup 5 | 41,2 | `e759ede01c2a909e3e4a40c81f77c2b93f0f33dcd4bb6476a752eecc878ac661` |
| backup 6 | 41,2 | `c078b5de4201b410872ad3973f2aecbeb1e2b510eadb9c9b82aa640c0c9aa718` |

⚠️ **Credencial exposta**: 5 `.pfx` + `.p12` **com a senha no nome do arquivo** (2 cópias idênticas, hash `e6d2207a…f3bb`, mais 4 únicos). Custódia manual, nunca versionar, tratar como incidente se a pasta for compartilhada.

## 8. Próxima ação

**M15 — corte/comercial**: identidades Auth dos 3 responsáveis (etapa `awaiting_auth_dispatch`), materialização de entidades nas tabelas `erp_*`, catálogo/estoque/PDV com os dados importados e jornada de venda. Relatórios agregados desta carga: `%TEMP%\connectioncyber-m14\load-summary-*.json` e `report-*.json`.
