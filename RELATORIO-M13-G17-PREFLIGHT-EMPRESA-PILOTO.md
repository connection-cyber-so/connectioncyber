# M13-G17 — preflight da primeira NF-e da empresa-piloto

Data: 29/08/2026
Ambiente: staging local
Decisão: **BLOQUEADO COM SEGURANÇA**

## Resultado

O motor fiscal global está apto a validar uma configuração individual, mas a NF-e modelo 55 da empresa-piloto não foi montada. O preflight determinístico recusou continuar porque 13 confirmações fiscais obrigatórias ainda não existem no repositório seguro.

## Bloqueios confirmados

1. Operação externa: credenciamento da empresa em homologação e correspondência entre o A1 e o emitente.
2. Cadastro fiscal: UF, código da UF, município IBGE, inscrição estadual e CRT.
3. Numeração: série e próximo número exclusivo de homologação.
4. Cenário tributário: NCM, CFOP, CSOSN e aprovação formal da operação fiscal.

Nenhum valor foi inferido, preenchido por padrão ou extraído de identidade armazenada.

## Evidências

- suíte fiscal: `209/209` testes aprovados;
- resultado: `M13_G17_PREFLIGHT_BLOCKED`;
- bloqueios: `13/13` detectados;
- XML gerado, assinado, persistido ou transmitido: `false`;
- protocolo, CSC, Supabase remoto e produção: não utilizados.

## Próxima ação permitida

M13-G18: implementar coleta local protegida, validação de formato e confirmação humana dos 13 requisitos. Os valores devem permanecer fora do Git, logs e documentação. Somente após o preflight retornar pronto poderá existir outro portão para montar e assinar a NF-e em memória.
