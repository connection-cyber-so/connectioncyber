# M15-G3 — Preparação do ensaio integrado descartável

Data: 30/08/2026

## Decisão

**Pacote local preparado. Execução remota permanece bloqueada.**

## Entregas

- preflight somente leitura com marcador determinístico;
- fixture transacional para MEI, ME e LTDA sintéticos;
- jornada de cadastro, catálogo, estoque, venda, caixa e financeiro;
- quatro violações cross-tenant esperadas;
- RLS e fiscal fail-closed verificados;
- 30 asserções pgTAP e `ROLLBACK` obrigatório;
- runbook com critérios de parada e prova de ausência residual;
- testes estáticos que impedem conta, identidade fiscal e escrita fiscal.

## Validação local

- contrato M15: **34/34 testes**;
- suíte consolidada do projeto: **371 testes** na baseline atual;
- marcador local preservado: `M15_G2_SYNTHETIC_JOURNEY_OK`;
- execução remota: não realizada.

## Limites

Nenhuma conexão ao Supabase, Vercel ou produção foi realizada. Nenhuma migration, conta, fixture ou dado foi aplicado remotamente.

## Próximo portão

Autorizar exclusivamente o preflight remoto e a execução transacional do M15-G3 no Supabase staging `ozvylnaipubrmaadikvk`, com `ROLLBACK`, 30 asserções e zero persistência.
