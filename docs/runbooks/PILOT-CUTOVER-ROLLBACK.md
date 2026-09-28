# Runbook — corte e rollback do piloto

Estado: template; produção permanece bloqueada.

Exigir aceite de segurança, backup, dados, fiscal, dispositivos, usuários, observabilidade e suporte. Qualquer pendência resulta em `NO-GO`.

## Corte

1. congelar origem e registrar último identificador/delta;
2. executar backup final e validar referência/hash;
3. importar delta por lote idempotente;
4. reconciliar contagens, estoque, caixa, financeiro e fiscal;
5. executar smoke tests e liberar somente após aceite nominal.

Rollback é obrigatório em divergência não aceita, cross-tenant, falha fiscal, perda de integridade, indisponibilidade acima do RTO ou ausência de observabilidade.
