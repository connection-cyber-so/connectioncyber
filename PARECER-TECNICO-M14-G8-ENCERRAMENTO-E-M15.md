# M14-G8 — Encerramento do importador e definição do M15

Data: 29/08/2026

## Decisão de encerramento

**M14 encerrado quanto à fundação global do importador, aplicado e validado em staging.**

O encerramento cobre contratos canônicos, manifesto de origem, idempotência, concorrência, isolamento por tenant, ledger, rejeições, reconciliação, RLS, rollback e ferramentas de validação. Ele não significa que um backup real já foi recebido, restaurado ou migrado.

## Evidências consolidadas

- Contrato e simulador: 24/24 testes iniciais; suíte final com 41/41.
- Migration `0031`, SHA-256 `860234c17a87009892485679553b46c8f271df2b9180de8c434e3765d2a8db1c`.
- Auditoria local: dois ciclos de 96/96, rollback, preflight e reaplicação.
- Validação transacional remota: 96/96 com `ROLLBACK` e zero resíduos.
- Aplicação persistente exclusiva no Supabase staging `ozvylnaipubrmaadikvk`.
- Pós-aplicação: 96/96, sete tabelas com RLS, cinco RPCs protegidas e zero dados.
- Histórico remoto alinhado até `0031`; dry-run sem migrations pendentes.
- Produção e dados reais permaneceram intocados.

## Pendências transferidas para execução por cliente

As etapas D1–D6 — receber cópia, calcular hash, inspecionar mídia, restaurar em laboratório, inventariar, adaptar, reconciliar e remover o laboratório — dependem de uma fonte real e serão executadas separadamente para cada tenant no M15. Nenhuma delas deve reutilizar credenciais, arquivos ou decisões fiscais entre empresas.

## Próximo módulo cronológico

**M15 — Piloto e implantação por cliente.**

Objetivo: provar o ciclo completo de habilitação de um tenant, migração simulada, validação operacional, corte, aceite, observabilidade e rollback antes de repetir o processo em ondas para outros clientes.

## Primeiro portão: M15-G0

M15-G0 será um parecer de prontidão do piloto, sem criar dados reais e sem acessar produção. Deve entregar:

1. matriz de prontidão da empresa-piloto Mania de Moda;
2. inventário dos bloqueios fiscal, credenciais, domínio, usuários, backup e operação;
3. plano de ambientes, backup, restauração, corte e rollback por tenant;
4. critérios de aceite funcionais, financeiros, fiscais, segurança e desempenho;
5. sequência determinística M15-G1 em diante, separando ações automáticas dos portões que exigem interação.

## Condição fiscal conhecida

A empresa-piloto está classificada como regime normal, mas a validação fiscal individual continua bloqueada até a confirmação cadastral e tributária esperada do contador em 31/08/2026. Isso não bloqueia o M15-G0 nem os testes sintéticos; bloqueia emissão fiscal real e corte de produção.

## Parecer

O projeto está pronto para iniciar M15-G0. Não está autorizado ainda a importar backup real, criar usuários reais, habilitar domínio público, transmitir documento fiscal, operar pagamentos reais ou executar corte em produção.
