# M15-G1 — Auditoria da baseline de segurança pré-piloto

Data: 30/08/2026

Escopo: repositório e ambiente local de staging, sem alterar ou consultar configurações privadas de Supabase, Vercel, GitHub ou produção.

## Decisão

**Reprovada para UAT com usuários reais. Liberada para remediação local e ensaio sintético após R1.**

Foram registrados 5 achados críticos, 6 altos e 4 médios. Nenhum segredo rastreado foi encontrado na varredura selecionada e os três aplicativos reportaram zero vulnerabilidades runtime no `npm audit --omit=dev`.

## Evidências executadas

| Componente | Resultado |
|---|---:|
| Site | 5/5 |
| Platform | 9/9 |
| Protocolo de dispositivos | 27/27 |
| Contrato fiscal | 234/234 |
| Contrato de importação | 41/41 |
| Portal | Bloqueado pelo Node 26 local; projeto exige Node 22 |
| Dependências runtime site/platform/portal | zero vulnerabilidades |
| `.env.local` do platform | ignorado pelo Git |
| Varredura de chaves privadas, JWTs e connection strings | nenhum segredo rastreado encontrado |

Total aprovado nesta rodada: **316 testes**. A falha do portal ocorreu antes dos testes, em `uv_os_get_passwd`, porque o terminal usa Node 26 fora da faixa `>=22 <23`; não foi classificada como falha funcional, mas impede aprovação integral.

## Achados críticos

1. Auth local permite signup, não exige confirmação, aceita senha mínima de 6 caracteres e mantém TOTP desativado.
2. Não existe prova mensurável de restauração, RPO ou RTO para o piloto.
3. A baseline local modela CIDRs irrestritos e não ativa enforcement de SSL; o estado hospedado exige auditoria separada.
4. Criação de usuários reais não pode preceder MFA, recuperação e procedimento break-glass testados.
5. Não há alertas operacionais, dono de incidente, health checks e runbook de hipercare implementados.

## Achados altos

- `apps/platform` e `apps/portal` não possuem a baseline de headers do site.
- O login do platform usa o parâmetro `redirect` sem allowlist explícita de caminho interno.
- O CI testa os três apps, mas omite device protocol, fiscal contract, import contract e gates SQL.
- Actions usam tags móveis `@v4`, sem pin por SHA.
- Ambiente local executa Node 26, divergindo do Node 22 contratado e usado no CI.
- Reset do Supabase mantém seed habilitado; fixtures de laboratório precisam ser separadas da política do piloto.

## Achados médios

- CSP do site ainda depende de `unsafe-inline`.
- O template do platform solicita segredo server-side sem consumidor atual identificado.
- CI não executa auditoria de dependências, scan de segredos, cancelamento concorrente ou bloqueio de artefatos gerados.
- A suíte do portal precisa ser repetida sob Node 22 antes do próximo aceite.

## Controles já aprovados

- `.env.local` está ignorado e nenhum arquivo de certificado/chave é rastreado.
- CI possui permissões `contents: read` e usa `npm ci`.
- Site já aplica CSP, anti-framing, `nosniff`, Referrer-Policy e Permissions-Policy.
- Middleware valida JWT por `getUser()` e portal usa redirect allowlisted.
- RLS, AAL2 em operações críticas, contratos fail-closed e service-role server-only possuem ampla cobertura SQL e unitária.
- Dependências runtime dos três apps não apresentaram vulnerabilidades conhecidas nesta consulta.

## Plano de remediação

### R1 — automático e somente local

1. criar headers compartilhados para platform e portal;
2. corrigir redirect do platform com allowlist e testes negativos;
3. fixar Node 22 por preflight/versionamento e repetir portal;
4. ampliar CI para pacotes críticos, SQL, audit e secret scan;
5. separar seed de laboratório e criar runbooks de backup, incidente e rollback.

### R2 — auditoria remota somente leitura, com autorização

Confirmar Auth hospedado, MFA, confirmação, proteção de senha vazada, network restrictions, SSL, advisors, backups disponíveis, variáveis Vercel e separação staging/produção.

### R3 — alterações remotas, cada grupo em portão próprio

Endurecer Auth, ativar MFA, restringir rede, configurar observabilidade e ajustar política de backup. Nenhuma dessas alterações foi executada neste G1.

### R4 — ensaio sintético M15-G2

Executar tenant sintético, cross-tenant negativo, recuperação, alertas, restauração, rollback e desempenho. Dados e usuários reais continuam proibidos.

## Critério para avançar

M15-G2 somente poderá iniciar após R1 concluir com portal aprovado em Node 22, testes e builds verdes, headers/redirect corrigidos e runbooks mínimos versionados. UAT real continuará bloqueada até R2/R3 e os portões fiscal, backup e dispositivos.
