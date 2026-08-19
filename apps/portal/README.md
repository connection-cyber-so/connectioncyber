# ConnectionCyber — Portal empresarial M03

Aplicação Next.js do ERP dos clientes. Este diretório é separado de:

- `apps/site`: site institucional, alunos e pagamentos;
- `apps/platform`: painel interno da equipe ConnectionCyber.

## Invariantes

O portal só autoriza acesso quando todas as condições forem verdadeiras:

1. hostname exato, ativo e verificado;
2. tenant ativo;
3. usuário validado por `supabase.auth.getUser()`;
4. membership ativa, vigente e pertencente ao próprio usuário;
5. tenant do hostname igual ao tenant da membership.

O campo legado `users.tenant_id`, valores enviados pelo navegador e o cookie
`cc_portal_membership` não autorizam acesso isoladamente. Staff sem membership
também não recebe bypass no portal.

## Desenvolvimento local

1. copie `.env.local.example` para `.env.local`;
2. use somente as variáveis do Supabase staging;
3. execute `npm install`;
4. execute `npm test`, `npm run type-check`, `npm run lint` e `npm run build`;
5. execute `npm run dev` para abrir `http://localhost:3021`.

Sem variáveis de ambiente, o aplicativo mostra um estado seguro de configuração
e não tenta acessar banco algum.

## Banco

O contrato está em:

- `supabase/migrations/0017_portal_tenant_resolution.sql`;
- `supabase/preflight/0017_portal_tenant_resolution_preflight.sql`;
- `supabase/tests/0017_portal_tenant_resolution.test.sql`;
- `supabase/rollback/0017_portal_tenant_resolution.rollback.sql`.

Neste portão, a migration é somente apresentada. Ela não deve ser aplicada em
staging remoto antes do próximo aceite. Depois de qualquer aplicação remota,
correções devem ser migrations forward-fix; o rollback destrutivo é exclusivo
de laboratório local descartável e exige confirmações explícitas.
