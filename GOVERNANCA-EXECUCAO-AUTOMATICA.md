# Governança de execução automática

**Vigência:** 01/09/2026

## Comunicação durante o processamento

- Exibir somente `GATE_EM_EXECUCAO`, bloqueio que exija decisão e `GATE_CONCLUIDO`.
- Suprimir narração de comandos, tentativas intermediárias e resultados repetitivos da conversa.
- Continuar automaticamente em implementação, testes, correções, documentação e validações autorizadas.
- Solicitar intervenção somente para credenciais protegidas, decisões materiais, escrita remota, identidade real, produção ou ação destrutiva.

## Registro técnico obrigatório

- Cada gate mantém relatório técnico próprio no repositório.
- `STATUS-MESTRE-DESENVOLVIMENTO.md` e `STATUS-MESTRE-DESENVOLVIMENTO.html` permanecem equivalentes e atualizados.
- O relatório registra escopo, alterações, testes, hashes ou marcadores aplicáveis, ambiente, riscos, decisão e próximo gate.
- A resposta final resume gate, resultado, testes, commit, efeitos remotos, relatório e próximo gate.

## Memória operacional

Este arquivo é a regra persistente do projeto. Em caso de compactação do contexto ou nova sessão, ele deve ser consultado antes de continuar a sequência de gates.
