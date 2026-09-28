# M15-G1-R1 — Remediação local da baseline pré-piloto

Data: 30/08/2026

## Decisão

**R1 concluída e aprovada localmente. M15-G2 sintético liberado; usuários reais e produção permanecem bloqueados.**

## Remediações

- Baseline compartilhada de CSP, anti-framing, `nosniff`, Referrer-Policy e Permissions-Policy aplicada a site, platform e portal.
- Redirect pós-login do platform limitado a rotas internas conhecidas, com testes positivos e negativos.
- Node 22 fixado em `.nvmrc`, `.node-version` e preflight obrigatório de dev, teste e build.
- CI ampliado para os três contratos críticos, audit runtime, scan de segredos, artefatos gerados e cancelamento concorrente.
- Actions oficiais fixadas por SHA.
- Seeds automáticos desativados; qualquer fixture passa a exigir ato explícito de laboratório.
- Runbooks mínimos versionados para backup/restauração, incidente/hipercare e corte/rollback.

## Quality gates em Node 22.23.2

| Componente | Testes | TypeScript | ESLint | Build |
|---|---:|---:|---:|---:|
| Site | 5/5 | aprovado | aprovado | aprovado |
| Platform | 11/11 | aprovado | aprovado | aprovado |
| Portal | 19/19 | aprovado | aprovado | aprovado |
| Device protocol | 27/27 | n/a | n/a | n/a |
| Fiscal contract | 234/234 | n/a | n/a | n/a |
| Import contract | 41/41 | n/a | n/a | n/a |

Total: **337/337 testes**.

Os três aplicativos reportaram zero vulnerabilidades após sincronização dos locks. O `next lint` apresentou comportamento preso/depreciado; a validação foi executada diretamente pela CLI ESLint e aprovada. A substituição definitiva do script legado pode ocorrer em manutenção separada.

## Limites

Nenhuma configuração hospedada, conta, tenant, dado real, DNS, backup, observabilidade externa, Vercel, Supabase remoto ou produção foi alterado.

## Próxima etapa

M15-G2: ensaio ponta a ponta com tenant e dados totalmente sintéticos, dentro de transação ou laboratório descartável, incluindo cross-tenant negativo, perfis MEI/ME/LTDA, cadastro, estoque, venda, caixa, financeiro, fiscal bloqueado e rollback.
