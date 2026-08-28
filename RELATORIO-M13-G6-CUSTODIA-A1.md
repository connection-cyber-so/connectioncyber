# M13-G6 — custódia segura A1 e validação da empresa-piloto

Data: 28/08/2026

## Resultado

- Política de custódia local implementada sem manipular certificado.
- A1 reservado para cofre externo; chave privada obrigatoriamente não exportável.
- Git e banco de dados recusados como armazenamento de material criptográfico.
- Inventário aceita somente metadados não secretos e hashes SHA-256.
- Importação, assinatura e transmissão exigem portões independentes.
- Empresa-piloto validada por identificador técnico e subdomínio, sem CNPJ completo.
- 78/78 testes locais aprovados.

## Evidência automática

`M13_G6_LOCAL_VALIDATION_OK`: ambiente homologação; certificado importado `false`; assinatura `false`; transmissão `false`; produção `false`.

O simulador fiscal continuou aprovado com `networkCall=false` e `fiscalValue=false`.

## Alterações externas

Nenhuma. Não houve instalação/importação de A1, leitura de senha, armazenamento de CSC, chamada à SEFAZ, alteração de Supabase ou acesso à produção.

## Próximo portão

M13-G7 deverá definir e autorizar separadamente o mecanismo operacional de importação local do A1 em armazenamento protegido. A validação deverá começar pela leitura dos metadados e da cadeia, ainda sem assinatura ou transmissão.

