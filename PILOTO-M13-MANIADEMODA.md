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

## Validação M13-G9

- XML exclusivamente sintético assinado em memória com o A1 instalado;
- assinatura criptográfica válida: `true`;
- cadeia válida: `true`;
- conteúdo sem identidade real: `true`;
- valor fiscal: `false`;
- chave privada exportada, XML persistido, CSC usado, transmissão e produção: `false`.

## Validação M13-G10

- pacote oficial NF-e `010e_v1.02` fixado com hashes SHA-256;
- NF-e modelo 55 em homologação gerada com identidade fiscal sintética;
- schema oficial válido: `true`;
- assinatura XMLDSig válida: `true`;
- cadeia válida: `true`;
- identidade da empresa-piloto ausente dos campos fiscais: `true`;
- XML persistido, CSC, transmissão e produção: `false`.

## Validação M13-G11

- chave de acesso sintética com 44 dígitos e módulo 11 validada;
- itens, descontos, acréscimos, pagamentos e total reconciliados em centavos;
- envelope `enviNFe` 4.00 montado somente em memória;
- lote derivado deterministicamente e reprocessamento sem duplicidade;
- conflitos e divergências geram rejeições locais estáveis;
- certificado, CSC, assinatura, persistência, transmissão e produção: `false`.

## Validação M13-G12

- ciclo local recebido, processamento, autorização e rejeição validado;
- timeout convertido em consulta posterior sem nova emissão;
- duplicidade reconciliada com protocolo existente;
- conflito de protocolo direcionado para revisão manual;
- documento único preservado após consulta e reprocessamento;
- rede, certificado, CSC, XML persistido, transmissão e produção: `false`.

## Validação M13-G17

- preflight individual executado localmente em modo fail-closed;
- 13 requisitos fiscais ausentes detectados sem inventar valores;
- credenciamento e correspondência do A1 permanecem sem confirmação;
- cadastro fiscal, numeração e cenário tributário permanecem bloqueados;
- suíte fiscal aprovada: `209/209`;
- XML gerado, assinado, persistido ou transmitido: `false`;
- Supabase remoto e produção: não acessados.

## Preparação M13-G18

- coletor local protegido criado para os 13 requisitos;
- entradas mascaradas e mantidas somente na memória do processo;
- correspondência UF/código/município e formatos fiscais validados;
- saída não revela os valores informados;
- suíte fiscal aprovada: `217/217`;
- coleta real ainda não executada e nenhum dado fiscal armazenado;
- XML, assinatura, transmissão, Supabase remoto e produção: não acessados.
