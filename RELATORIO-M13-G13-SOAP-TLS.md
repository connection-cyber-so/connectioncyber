# M13-G13 — arquitetura SOAP/TLS de homologação

Data: 28/08/2026

## Resultado

- Catálogo de homologação versionado a partir da Relação de Serviços Web do Portal Nacional da NF-e.
- As 27 UFs foram roteadas sem duplicidade entre SVRS, SVAN e autorizadores próprios.
- Serviços essenciais versionados: autorização, retorno da autorização, consulta protocolo e status.
- Envelope SOAP 1.2 com correlação determinística implementado.
- mTLS definido exclusivamente por referência de chave não exportável.
- Timeout fixo em 15 segundos e uma única tentativa automática.
- Cliente fail-closed sem implementação de transporte e com portão de rede fechado.
- 182/182 testes locais aprovados.

## Controles

Rede, certificado, CSC, assinatura, transmissão, produção e Supabase remoto permaneceram inalterados/desativados.

## Próximo portão

M13-G14 — auditoria técnica do catálogo por endpoint oficial e prova TLS somente de conectividade em homologação, sem envio de conteúdo fiscal.

