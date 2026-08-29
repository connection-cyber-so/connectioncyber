# M13-G10 — NF-e canônica de homologação

Data: 28/08/2026

## Fonte oficial fixada

- Portal: `https://www.nfe.fazenda.gov.br/portal/listaConteudo.aspx?tipoConteudo=BMPFMBoln3w=`
- Pacote: `010e_v1.02`, publicado em 10/07/2026.
- SHA-256 do ZIP: `d44ae5aa6a0d1cabf6235d2d2d47b75be5dd87bc6b90a7ec3dcec99c3d41bda1`.
- Cinco XSDs extraídos e verificados individualmente pelo manifesto versionado.

## Resultado

- NF-e 4.00, modelo 55 e ambiente 2 gerados exclusivamente em memória.
- Identidade fiscal dos campos do XML inteiramente sintética.
- XMLDSig ajustado ao perfil fixado pelo XSD oficial: RSA-SHA1, SHA-1 e certificado público em `KeyInfo/X509Data`.
- Certificado público permaneceu somente em memória, conforme autorização complementar.
- Validação XSD: `true`.
- Validação da assinatura: `true`.
- Validação da cadeia: `true`.
- Identidade da empresa-piloto ausente dos campos fiscais: `true`.
- 128/128 testes locais aprovados.

## Controles preservados

- valor fiscal: `false`;
- XML persistido: `false`;
- chave privada exportada: `false`;
- CSC utilizado: `false`;
- transmissão: `false`;
- produção acessada: `false`;
- Supabase remoto alterado: `false`.

## Próximo portão

M13-G11 — regras de negócio NF-e locais: composição e dígito da chave, consistência dos totais, envelope `enviNFe`, idempotência e rejeições determinísticas, ainda sem transmissão.

