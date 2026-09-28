# M13-G18 — coleta fiscal protegida

Data: 29/08/2026
Ambiente: staging local
Decisão: **MECANISMO APROVADO; COLETA REAL NÃO EXECUTADA**

## Entrega

Foi criado um coletor local fail-closed para os 13 requisitos do preflight individual. Todas as entradas são mascaradas, existem somente na memória do processo e são removidas ao final, inclusive em caso de falha.

## Validações

- correspondência determinística entre UF e código IBGE;
- município vinculado ao código da UF;
- formato de inscrição estadual, CRT, série e número;
- NCM, CFOP de saída e conjunto permitido de CSOSN;
- confirmações explícitas de credenciamento, A1 e operação fiscal;
- resultado limitado ao estado e aos nomes dos bloqueios, sem imprimir valores.

## Evidências

- suíte fiscal: `217/217` testes aprovados;
- parser PowerShell: `M13_G18_POWERSHELL_PARSE_OK`;
- script PowerShell: somente ASCII;
- escrita em arquivo ou banco: ausente;
- XML, assinatura, CSC, transmissão, Supabase remoto e produção: não utilizados.

## Portão operacional

A execução real exige que o responsável informe localmente os valores fiscais confirmados. O sistema não possui autorização para inferir NCM, CFOP, CSOSN, IE, CRT, série, número ou credenciamento. A saída obrigatória para avançar é `M13_G18_PROTECTED_CONFIG_OK`.
