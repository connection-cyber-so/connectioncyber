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

## Por que não importei os 10 CNPJ do documento original

O parecer fonte lista 10 empresas reais (varejo: confeitaria, moda, tecidos, material de
construção, oficinas, doces) povoadas no **staging do `bpo-system-web-os`**, vinculadas ao tenant
"Connection Cyber Assessoria" daquele sistema. Elas não têm relação nenhuma com o
ConnectionCyberSO — importar o CNPJ e nome dessas empresas para `tenants` aqui seria apresentar
empresas reais como clientes de uma plataforma com a qual elas não têm vínculo, exatamente o
risco que o próprio documento fonte identifica e pede confirmação explícita antes de agir.

Some a isso um problema estrutural: `bpo-system-web-os` tem projetos Supabase de staging e
produção **separados**, então dado de demonstração fica isolado do que um dia é auditado como
produção. **O ConnectionCyberSO hoje tem um projeto Supabase só** (`qfggetvashdxyuvlhihq`) — não
existe ainda um lugar seguro para povoar dado de demonstração sem ele entrar "em produção".

## O que fica pronto para usar, quando fizer sentido

- A Edge Function `lookup-cnpj` já resolve o passo 1 sem trabalho adicional.
- O padrão de "CNAE decide módulo, módulo decide cenário" pode ser aplicado a um tenant real
  assim que ele existir — via `tenant_modules.status = 'diagnosticado'` inicialmente, sem
  precisar de nenhuma tabela nova.
- Se um dia fizer sentido povoar tenants de demonstração de verdade (ex: para uma apresentação
  comercial), o pré-requisito técnico é ter uma separação staging/produção real no Supabase — o
  parecer técnico #001 já cita o Supabase Branching como caminho para isso.

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
