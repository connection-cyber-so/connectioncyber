# M13-G7 — preparação da importação protegida do A1

Data: 28/08/2026

## Resultado

- Fluxo de inspeção efêmera implementado por adaptadores restritos.
- Entrada de senha modelada como segredo opaco, não serializável e mascarado.
- Material PKCS#12 e senha são zerados em memória após sucesso ou falha.
- Inspeção exige cadeia válida e proíbe extração da chave privada e assinatura.
- Persistência aceita somente referência opaca, hashes e validade.
- Adaptadores persistentes e contêineres inválidos são recusados.
- 88/88 testes locais aprovados.

## Evidência automática

`M13_G7_IMPORT_PREPARATION_OK`: cadeia válida; material persistido `false`; chave extraída `false`; assinatura `false`; transmissão `false`; buffers eliminados `true`.

## Escopo preservado

Foi usado exclusivamente material sintético em memória. Nenhum A1 real foi solicitado, aberto, importado ou instalado. Nenhuma senha, CSC, identidade completa, XML fiscal ou dado de cliente foi armazenado. Supabase, SEFAZ e produção não foram acessados.

## Próximo portão

M13-G8 — selecionar localmente o arquivo A1 da empresa-piloto por diálogo protegido e inspecionar somente metadados/cadeia. Esse portão exigirá autorização específica, interação local do responsável e definição do armazenamento protegido disponível no Windows.

