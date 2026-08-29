# M13-G9 — assinatura local controlada

Data: 28/08/2026

## Resultado

- Certificado válido selecionado no repositório pessoal do Windows em modo somente leitura.
- XML sintético, sem CNPJ, CPF ou valor fiscal, construído exclusivamente em memória.
- Assinatura RSA-SHA256 e resumo SHA-256 executados pela chave privada instalada.
- Assinatura validada localmente com a chave pública.
- Cadeia local aprovada.
- 113/113 testes locais aprovados.

## Evidência booleana

- `signatureValid=true`
- `chainValid=true`
- `identityFree=true`
- `fiscalValue=false`
- `privateKeyExported=false`
- `xmlPersisted=false`
- `cscUsed=false`
- `transmitted=false`
- `productionAccessed=false`

Nenhum XML, certificado, senha, titular, CNPJ ou impressão digital foi registrado. Supabase, SEFAZ e produção não foram acessados.

## Próximo portão

M13-G10 — gerar e validar localmente um XML NF-e de homologação conforme contrato canônico e schemas fiscais, usando dados sintéticos e sem transmissão. NFC-e/CSC continuará bloqueado em portão próprio.

