# M13-G12 — ciclo local de autorização NF-e

Data: 28/08/2026

## Resultado

- Máquina de estados explícita para rascunho, envio, recebimento, processamento, timeout, consulta, autorização, rejeição e ausência.
- Estados terminais impedem regressão indevida.
- Simulador determinístico cobre autorização, rejeição, timeout e duplicidade autorizada.
- Timeout gera consulta por recibo, nunca uma nova emissão automática.
- Consulta posterior importa o protocolo mantendo um único documento.
- Reenvio idêntico retorna duplicidade com o protocolo existente.
- Mesma chave com conteúdo divergente gera rejeição de conflito.
- Protocolos divergentes exigem revisão manual.
- 168/168 testes locais aprovados.

## Evidência automática

`M13_G12_AUTHORIZATION_SIMULATOR_OK`: timeout tratado, consulta autorizada, duplicidade reconciliada, protocolo importado e contagem final de um documento.

## Controles preservados

- chamada de rede: `false`;
- certificado utilizado: `false`;
- CSC utilizado: `false`;
- XML persistido: `false`;
- transmissão: `false`;
- produção acessada: `false`;
- Supabase remoto alterado: `false`.

## Próximo portão

M13-G13 — arquitetura do transporte SOAP de homologação, catálogo de endpoints por UF/autorizador, TLS mútuo e cliente fail-closed, inicialmente com adaptador bloqueado e testes sem rede.

