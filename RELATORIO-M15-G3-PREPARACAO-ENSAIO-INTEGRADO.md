# M15-G3 — Preparação do ensaio integrado descartável

Data: 30/08/2026

## Decisão

**Pacote local preparado e posteriormente aprovado no staging com rollback.**

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
- execução remota autorizada: aprovada com rollback e zero resíduos.

## Limites

Na preparação local, nenhuma conexão foi realizada. Após autorização específica, o ensaio foi executado exclusivamente no Supabase staging e terminou com zero tenants, contas ou documentos fiscais residuais. Vercel e produção não foram acessados.

## Próximo portão

M15-G4: parecer de prontidão do piloto visual e definição do primeiro fluxo demonstrável com interface, ainda sem usuários ou dados reais.
