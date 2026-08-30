# Runbook — backup e restauração do piloto

Estado: template; nenhuma operação remota autorizada.

- RPO proposto: 15 minutos; depende de aceite e capacidade do plano.
- RTO proposto: 60 minutos; depende de teste cronometrado.
- Backup anterior ao corte identificado por referência opaca e hash.
- Restauração primeiro em destino isolado, nunca sobre o banco ativo.
- Validação de versão, migrations, RLS, contagens, checksums e smoke tests.

## Sequência

1. registrar janela, responsáveis, origem e destino;
2. confirmar backup e hash sem copiar segredo para o projeto;
3. restaurar em ambiente isolado;
4. executar validações e medir duração;
5. registrar go/no-go e destruir o laboratório somente após aceite.

Falha em qualquer etapa implica `NO-GO`; restauração em produção exige portão separado.
