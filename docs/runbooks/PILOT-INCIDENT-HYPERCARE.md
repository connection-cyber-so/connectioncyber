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

## Métricas mínimas e resposta

| Sinal | Limite local proposto | Resposta |
|---|---:|---|
| Evento cross-tenant | zero | SEV-1, bloquear operação e avaliar rollback |
| Evento fiscal indevido | zero | SEV-1, bloquear emissão e avaliar rollback |
| Disponibilidade | mínimo 99,5% | SEV-2 abaixo do limite |
| Taxa de erro | máximo 1% | SEV-2 acima do limite |
| Latência p95 | máximo 1.200 ms | SEV-2 acima do limite |
| Reconciliações pendentes | zero | SEV-2 e bloquear aceite final |

## Aceite final

O aceite real exige métricas coletadas após corte autorizado, reconciliação sem pendências, zero incidente SEV-1 aberto, responsáveis identificados e aprovação formal do cliente e da ConnectionCyber. O simulador local nunca concede aceite nem autorização de produção.
