# Piloto M13 — Mania de Moda

- tenant/subdomínio: `maniademoda.connectioncyber.com.br`;
- CNPJ no repositório: `09.***.***/0001-10` (mascarado);
- segmento: roupas e calçados masculinos, femininos e infantis;
- característica: operação sazonal e multissegmento;
- ambiente deste portão: somente simulação local de homologação.

Proibido neste estágio: importar/instalar A1, armazenar senha/PFX/CSC, transmitir à SEFAZ, gerar chave/protocolo/XML válido, criar dados no Supabase ou acessar produção. A identidade completa e as credenciais da empresa-piloto permanecem em portão separado.

## Validação M13-G6

- identificador técnico: `pilot-maniademoda`;
- cofre definido: externo, por referência opaca e chave não exportável;
- inventário futuro: somente hashes do titular e impressão digital, validade e referência;
- importação A1: desativada;
- assinatura: desativada;
- transmissão: desativada;
- produção: desativada.

## Validação M13-G7

- fluxo de leitura efêmera preparado;
- senha representada por segredo opaco e sempre mascarado;
- contêiner e senha eliminados da memória após sucesso ou falha;
- chave privada não extraída;
- saída limitada a referência, hashes, validade e estado da cadeia;
- nenhum certificado real foi aberto ou importado.

## Validação M13-G8

- certificado selecionado no repositório pessoal do Windows em modo somente leitura;
- validade atual confirmada: `true`;
- cadeia local confirmada: `true`;
- senha não solicitada pelo inspetor;
- titular, CNPJ, impressão digital e material criptográfico não registrados no projeto;
- chave privada não exportada, assinatura e transmissão não executadas.
