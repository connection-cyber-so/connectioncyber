# Metodologia de povoamento de tenant via CNPJ + cenário por CNAE

> Trazida da auditoria de `C:\Users\joaqu\Downloads\BPO\documentacao\Parecer_Tecnico_Povoamento_CNPJ_CNAE.docx`
> (projeto `bpo-system-web-os`) — documenta o **padrão**, não importa os dados específicos que o
> documento original usa. Ver seção "Por que não importei os 10 CNPJ" abaixo.

## O que é

Um jeito de fazer um tenant novo (ou um ambiente de demonstração) nascer "vivo" — com dado
cadastral real e cenário de módulo plausível — em vez de começar com telas de cadastro vazias.

1. **Consulta de CNPJ** pela nossa própria Edge Function `lookup-cnpj` (já implantada e testada
   nesta sessão) — devolve razão social, CNAE principal/secundários, porte, situação cadastral,
   município/UF, data de abertura.
2. **CNAE decide quais módulos fazem sentido para aquele tenant**, não um pacote fixo igual pra
   todo mundo. Uma confeitaria não recebe cenário de "suporte de infraestrutura em nuvem"; uma
   oficina de usinagem não recebe cenário de "atendimento ao cliente" se isso não for realista
   pro porte/segmento dela. Isso já é coerente com `module_catalog` + `tenant_modules`
   (`docs/auditoria-ecossistema-connectioncyberos.md`) — o CNAE só entra como um critério a mais
   para decidir **quais** módulos habilitar por padrão para aquele tenant, e com qual status
   inicial (`diagnosticado` antes de `ativo`).
3. **Separação de risco por tipo de dado**: dado cadastral (CNPJ, razão social, CNAE, endereço)
   é registro público da Receita Federal — risco baixo. Qualquer "situação a resolver" associada
   a um módulo, se descrever um problema real e identificável de uma empresa real, é informação
   de negócio sensível dela — mesmo em ambiente de teste. A regra: cenário sempre
   fictício-mas-realista (ancorado em CNAE/porte), nunca um problema real de uma empresa real,
   a menos que essa empresa seja de fato cliente com anuência explícita para uso do nome dela.

## Atualização — 2026-08-13: confirmado como clientes reais, implementado

Na sessão seguinte, Joaquim Coelho confirmou explicitamente: *"Todas as empresas mencionadas — e
todas que eu solicitar para adicionar — são clientes com os quais já mantenho contrato"*. Isso
resolve a ressalva original deste documento. Com a confirmação, os 10 CNPJ do parecer fonte foram
trazidos para `connectioncyber` como tenants reais:

1. Migration `0005_tenants_dados_cadastrais.sql` — estendeu `tenants` com `cnpj`, `razao_social`,
   `cnae_principal`, `cnae_descricao`, `porte_receita`, `situacao_cadastral`, `municipio`, `uf`,
   `data_abertura`, `natureza_juridica`, `dados_receita_raw` (jsonb) — mesmo padrão de
   `bpo_clients` no `bpo-system-web-os`.
2. Os 10 CNPJ foram consultados **ao vivo** via nossa própria `lookup-cnpj` (não copiados do
   documento fonte) — dado cadastral 100% atual no momento do povoamento, confirmado `ATIVA` para
   todas as 10 empresas.
3. Migration `0006_povoamento_tenants_reais.sql` — inseriu os 10 tenants, `vertical = 'varejo'`,
   com o retorno bruto da Receita Federal preservado em `dados_receita_raw`.
4. **Nenhum módulo foi habilitado automaticamente** em `tenant_modules` para esses tenants — qual
   serviço cada cliente contrata de fato é informação de negócio real que só o Joaquim pode
   confirmar; não foi inferida nem inventada a partir do CNAE.

### Achado de segurança durante a verificação (corrigido na hora)

Ao validar o povoamento, uma consulta com a `service_role` key (acesso administrativo) foi
recusada com erro `42501 — permission denied`. Diagnóstico: nenhuma migration anterior (0001-0006)
tinha concedido `GRANT` de tabela para nenhum papel — só RLS tinha sido habilitado. RLS filtra
**linhas**; `GRANT` é o pré-requisito de acesso que vem antes disso, e estava ausente até para o
`service_role`. Corrigido em duas migrations:

- `0007_grants_authenticated_service_role.sql` — concedeu `GRANT` para `service_role` (acesso
  total, papel interno) e `authenticated`.
- `0008_corrige_escopo_grants_authenticated.sql` — **autocorreção imediata**: a primeira versão
  do grant a `authenticated` era ampla demais (INSERT/UPDATE/DELETE em todas as tabelas,
  inclusive as que não têm RLS habilitado, como `courses`/`products`/`cms_content` — o que
  deixaria qualquer usuário logado editar o catálogo). Corrigido para `authenticated` ter só
  `SELECT` por padrão, com `INSERT/UPDATE/DELETE` explícito apenas nas tabelas que já têm RLS +
  policy própria validada (`tenants`, `users`, `enrollments`, `orders`, `tenant_modules`,
  `tenant_themes`). Escrita administrativa (cursos, produtos, CMS) continua via `service_role` em
  API routes, como o código já fazia.

## Empresas confirmadas como clientes, ainda sem CNPJ fornecido (pipeline, não são tenants ainda)

Citadas por Joaquim Coelho na mesma confirmação, como parte da entrada gradual planejada — **não
foram criadas como tenants**, porque não há CNPJ para consultar ainda. Entram no mesmo processo
(consulta via `lookup-cnpj` → `tenants`) assim que o CNPJ de cada uma for fornecido:

1. Oficina mecânica com loja de produtos
2. Distribuidora de águas
3. Fábrica e comércio de sorvetes
4. Rede de restaurantes (5 unidades)
5. Empresa coletora de óleo lubrificante
6. Grupo iGreen — energia solar, seguros de veículos e telecom (chips)
7. Empresa com 2 lojas de manutenção de celulares/notebooks/computadores/eletroeletrônicos

**Convenção adotada a partir de agora**: toda empresa tratada como tenant real fica documentada
como tal, com a fonte da confirmação. Sempre que uma empresa mencionada não for cliente real,
isso será registrado explicitamente (definição do próprio Joaquim).

## O que fica pronto para usar

- A Edge Function `lookup-cnpj` resolve a consulta de CNPJ sem trabalho adicional — já usada nos
  10 tenants acima e pronta para as próximas 7 empresas.
- O padrão de "CNAE decide módulo" pode ser aplicado a qualquer um dos 10 tenants a qualquer
  momento, via `tenant_modules.status = 'diagnosticado'`, assim que o Joaquim confirmar qual
  serviço cada um contrata.

## Padrões correlatos encontrados na mesma auditoria (para `apps/platform`, ainda não iniciado)

Dois padrões adicionais do `bpo-system-web-os`, relevantes para quando o sistema em si começar
a ser construído — registrados aqui, não implementados agora:

- **RBAC por pilar/módulo**: tabela `user_module_access` (qual usuário acessa qual pilar/módulo)
  + função `get_authorized_departments()`. Hoje o ConnectionCyberSO só tem papel global
  (`admin`/`instrutor`/`aluno`/...), sem granularidade por módulo dentro do mesmo tenant.
- **Registro operacional genérico**: em vez de uma tabela por pilar com colunas fixas
  (`ti_tickets`, `financeiro_lancamentos`...), um núcleo comum
  (`id, tenant_id, title, description, status, assigned_to, created_by, created_at, closed_at`)
  mais uma coluna `metadata jsonb` para o que é específico de cada módulo, e um esquema de
  eventos genérico (`campo_alterado` + nome do campo) em vez de um tipo de evento fixo por
  módulo. Evita recriar a mesma tabela quatro vezes conforme novos módulos entram.
