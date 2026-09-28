# M18-G21 — provisionamento do piloto no staging

Data: 01/09/2026

Ambiente: Supabase staging `ozvylnaipubrmaadikvk`

Resultado: **APROVADO E PROVISIONADO**

## Evidências

- Preflight PostgreSQL somente leitura: `M18_G20_REMOTE_PREFLIGHT_OK`.
- Preflight Auth confirmou e-mail ausente: `M18_G21_AUTH_PREFLIGHT_OK`.
- Executor fail-closed validado com parser, ASCII e 11/11 testes focados.
- Provisionamento: `M18_G21_PROVISIONING_OK`.
- Verificação remota: 1 tenant, 1 estabelecimento, 1 membership e 1 outbox com status `sent`.
- Ledger de provisionamento: 1 run com status `completed`.
- Zero compensações; usuário owner exige MFA/AAL2.
- Quality gates pós-aplicação: testes da plataforma, TypeScript, ESLint e build aprovados com Node.js 22.

## Segurança

- CNPJ, IE, razão social e e-mail foram descriptografados somente em memória.
- Chave `service_role` foi obtida pela CLI autenticada e mantida somente em memória.
- Nenhum segredo ou valor protegido foi escrito no projeto, Git, logs ou relatório.
- Produção não foi acessada.

## Incidente controlado

- Duas tentativas iniciais falharam antes de qualquer gravação devido à incompatibilidade do Windows PowerShell 5.1 com a chave retornada pela CLI.
- Diagnóstico remoto confirmou zero resíduos antes da repetição.
- O executor remoto foi fixado ao PowerShell atual; o preflight Auth respondeu com sucesso antes da aplicação.

## Próximo portão

M18-G22 — ativação controlada do acesso do usuário-piloto, confirmação do convite, cadastro de MFA e primeira jornada visual somente no staging. Exige interação do usuário convidado para aceitar o convite e configurar MFA.
