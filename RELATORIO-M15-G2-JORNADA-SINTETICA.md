# M15-G2 — Jornada sintética ponta a ponta da empresa-piloto

Data: 30/08/2026

## Decisão

**Jornada local aprovada. Nenhuma conta, tenant, dado real ou registro remoto foi criado.**

## Cobertura executada

- perfis jurídicos sintéticos MEI, ME e LTDA;
- autenticação com MFA obrigatório para `owner` e `admin`;
- membership e autorização por tenant e papel;
- bloqueio cross-tenant negativo;
- cadastro, catálogo, estoque, venda, caixa e financeiro;
- idempotência e conflito determinístico;
- módulo fiscal mantido em `fail-closed`;
- rollback integral do laboratório.

## Evidência

- marcador: `M15_G2_SYNTHETIC_JOURNEY_OK`;
- testes do laboratório: **24/24**;
- tenants sintéticos: 3;
- operações sintéticas: 6;
- registros depois do rollback: 0;
- acesso remoto: não;
- acesso à produção: não;
- persistência: não.

## Quality gates globais

- testes: **361/361**;
- TypeScript: aprovado nos três aplicativos;
- ESLint: aprovado nos três aplicativos;
- builds: aprovados para site, platform e portal;
- scan de segredos rastreados: aprovado.

## Limite técnico

Este gate comprova os contratos e controles locais. Ele não substitui um ensaio integrado contra o Supabase staging, que dependerá de autorização específica e continuará proibido de criar dados reais.

## Próxima etapa

M15-G3: parecer e preparação do ensaio integrado descartável no Supabase staging, com plano SQL transacional, fixtures sintéticas e `ROLLBACK`; nenhuma execução remota sem novo portão.
