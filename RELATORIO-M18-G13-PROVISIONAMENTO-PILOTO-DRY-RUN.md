# M18-G13 — provisionamento protegido do piloto em dry-run

Data: 01/09/2026

Ambiente: Supabase staging `ozvylnaipubrmaadikvk`

Resultado: **APROVADO SEM CRIAÇÃO DE DADOS OU IDENTIDADES**

## Escopo validado

- Planejador determinístico e não executável para o tenant `maniademodas`.
- Identidade jurídica, CNPJ, IE e e-mail aceitos somente por referências protegidas.
- Usuário-piloto definido como convite pendente, papel `owner`, MFA obrigatório e AAL2.
- Treze ações planejadas com idempotência, auditoria e verificação pós-aplicação.
- `--apply`, produção, rede, banco e Auth permanecem bloqueados.

## Evidências

- Dry-run: `M18_G13_PILOT_DRY_RUN_OK`.
- Hash do plano: `483af4979d11e6ce06083e03887a1c5dea3bb337603d44be8d2c61da5c286847`.
- Preflight remoto: `M18_G13_PILOT_PREFLIGHT_OK`.
- SHA-256 do preflight: `94F5973F0DA6CA1B1D0FEE993571F0DD320F8D85080EA2369626B596A6902D8A`.
- Testes: M18-G13 14/14; plataforma 107/107; contrato 50/50; adaptador 44/44.
- TypeScript, ESLint e build Next.js aprovados com Node.js 22.23.2.

## Estado remoto confirmado

- Tenant e domínio do piloto ausentes.
- Oito relações necessárias presentes.
- RLS ativa nas seis relações operacionais verificadas.
- Permissões `identities.read`, `identities.manage` e `mfa.enforce` presentes.
- Nenhuma conta, tenant, estabelecimento, membership, papel, fixture ou dado real criado.
- Nenhuma migration aplicada e produção não acessada.

## Próximo portão

M18-G14 deve preparar e auditar localmente o executor transacional e o rollback do provisionamento. A criação efetiva do tenant e do usuário-piloto no Supabase staging exigirá autorização separada e dados protegidos disponíveis no ambiente operacional.
