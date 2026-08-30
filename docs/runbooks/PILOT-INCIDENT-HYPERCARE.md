# Runbook — incidente e hipercare do piloto

Estado: template; contatos reais permanecem fora do Git.

- SEV-1: cross-tenant, perda de dados, fiscal indevido ou indisponibilidade total — bloquear operação e acionar rollback.
- SEV-2: função crítica degradada sem perda — conter, comunicar e corrigir na janela.
- SEV-3: função não crítica — registrar backlog com evidência técnica.

## Fluxo

1. abrir incidente com tenant, horário, versão, impacto e correlação, sem PII;
2. designar comandante, operação, comunicação e registro;
3. conter credenciais, emissão, pagamentos ou acesso conforme o domínio;
4. decidir correção ou rollback pelos critérios do corte;
5. encerrar com causa raiz, ações e teste de não regressão.
