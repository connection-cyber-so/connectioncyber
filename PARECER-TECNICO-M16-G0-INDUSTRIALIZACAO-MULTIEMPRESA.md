# M16-G0 — industrialização multiempresa e implantação em ondas

Data: 30/08/2026

## Decisão cronológica

Não havia gate formal registrado após o M15-G11. O M15 permanece pendente em sua parte operacional real: UAT, corte, hipercare e aceite dependem da empresa-piloto. Para que o desenvolvimento global continue sem ultrapassar esse portão, fica criado o M16 como trilha local de industrialização da plataforma para múltiplos clientes.

**Parecer:** viável avançar localmente. Produção, serviços remotos, identidades reais e dados reais permanecem bloqueados.

## Objetivo do M16

Transformar a base validada em um produto repetível para MEI, ME e LTDA, com um único núcleo versionado, isolamento por tenant, módulos habilitados por contrato e implantação em ondas determinísticas.

```text
                    NÚCLEO ÚNICO VERSIONADO
      identidade · tenant · auditoria · cadastros · fiscal
                              |
              +---------------+---------------+
              |               |               |
          Perfil MEI       Perfil ME       Perfil LTDA
          módulos A/B      módulos A–E      módulos A–G
              |               |               |
          Tenant 001       Tenant 002       Tenant 003...
          RLS isolada      RLS isolada      RLS isolada
```

## Evidências locais

- 31 migrations versionadas até `0031_m14_import_ledger.sql`;
- três aplicações separadas: `site`, `platform` e `portal`;
- pacotes canônicos para núcleo, periféricos, fiscal, importação e piloto;
- resolução explícita de tenant por domínio e membership;
- módulos visuais integrados para cadastro, estoque, venda, caixa e financeiro;
- testes de isolamento, idempotência, rollback e fail-closed já existentes.

## Arquitetura escolhida

1. Uma base de código e uma linha de migrations para todos os clientes.
2. Dados separados logicamente por `tenant_id`, com RLS obrigatória e testes negativos.
3. Catálogo canônico de capacidades; nenhum `if` espalhado por CNPJ ou nome de cliente.
4. Planos e exceções representados por entitlements versionados e auditáveis.
5. Customização por configuração e adaptadores; fork por cliente somente com parecer excepcional.
6. Implantação em ondas: laboratório sintético, staging isolado, UAT, go/no-go e produção.

## Riscos e controles

| Risco | Controle obrigatório |
|---|---|
| cliente enxergar outro tenant | host + membership + RLS + testes cross-tenant |
| atualização global quebrar exceção local | contrato de capacidades + matriz de compatibilidade |
| plano comercial virar autorização técnica | autorização server-side; interface nunca é autoridade |
| configuração incompleta liberar operação | defaults deny e estado `blocked` |
| rollout simultâneo ampliar impacto | ondas pequenas, canário, métricas e rollback |
| divergência de versão entre clientes | release imutável e registro de versão por tenant |

## Sequência determinística M16

| Gate | Entrega | Escopo permitido |
|---|---|---|
| M16-G0 | parecer, arquitetura e sequência | local, concluído |
| M16-G1 | contrato canônico de capacidades, planos e exceções | local, sintético |
| M16-G2 | motor de resolução fail-closed e matriz MEI/ME/LTDA | local, sintético |
| M16-G3 | migration local `0032`, RLS, preflight e pgTAP | local; remoto bloqueado |
| M16-G4 | auditoria e remediação independente da `0032` | local |
| M16-G5 | validação transacional em staging com rollback | autorização remota específica |
| M16-G6 | aplicação persistente em staging | autorização remota específica |
| M16-G7 | painel administrativo de capacidades | local primeiro |
| M16-G8 | simulador de rollout em ondas e rollback | local, sintético |

## Próxima etapa automática

**M16-G1 — contrato canônico de capacidades, planos e exceções por tenant, com testes sintéticos e sem migration remota.**

## Marcador

`M16_G0_MULTI_TENANT_PRODUCTIZATION_APPROVED`
