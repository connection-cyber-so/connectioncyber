# Parecer técnico de ação — acesso real para Mania de Modas + 2 clientes imediatos

Data: 07/09/2026

## 0. Achado crítico — muda a ordem de tudo

Antes de planejar quem entra e quando, dois fatos do código real precisam entrar na decisão,
porque nenhum dos dois é conhecido do usuário e ambos bloqueiam o pedido ("disponibilizar
acesso pra ele ir cadastrando dado real") tal como está hoje:

### 0.1 — Nenhuma tela de cadastro grava dado real ainda, nem a da Mania de Modas

`apps/platform/src/features/persistence/selected.ts` e
`packages/visual-persistence-supabase-adapter/src/index.mjs`:

```js
export const persistentVisualWritesEnabled = false;   // hardcoded
```

O seletor de modo só aceita `'synthetic'` (memória, **some ao reiniciar o servidor** — é
literalmente o aviso que já aparece na tela `/cadastros`: *"Os registros desaparecem ao
reiniciar o servidor"*) ou `'persistent-read-only'` (lê o Supabase real, mas todo `execute()` —
ou seja, toda escrita — devolve `CAPABILITY_REQUIRED` de propósito, sem exceção). O terceiro
modo (`'persistent'`, escrita de verdade) **existe só como erro**: `fail('PERSISTENT_WRITES_DISABLED')`.

Isso não é um bug — é uma decisão de segurança deliberada do M18 (rollout em fases: primeiro
prova o schema/RLS/UI só com leitura real e escrita sintética, só depois liga escrita real).
Só nunca foi para o próximo passo. Consequência prática: mesmo o cadastro elevado no M20-G6
(máscara de CPF/CNPJ, CEP automático) grava só em memória — cadastrar a Mania de Modas hoje
apagaria tudo no próximo `npm run dev`/deploy.

### 0.2 — `apps/platform` é só da equipe; o cliente nunca loga lá

`(painel)/layout.tsx` chama `is_platform_staff()` e bloqueia qualquer usuário que não seja
staff da ConnectionCyber, antes de mostrar qualquer menu. Isso é por desenho, documentado no
`CLAUDE.md` do projeto — não é algo a mudar.

O app que o **cliente** de fato loga é `apps/portal`. Só que o módulo real de Cadastros lá
está travado — conferido agora em `apps/portal/src/app/(portal)/dashboard/page.tsx`:

> "O shell M03 está em modo somente leitura. Cada módulo será liberado após seu portão de
> validação." — Cadastros aparece como card "Previsto para M05", sem link, sem formulário.

### 0.3 — o que isso significa junto

Hoje, **nenhum cliente (nem a Mania de Modas, que já tem tenant/estabelecimento/login desde o
M18-G21/G22) consegue logar em lugar nenhum e cadastrar um produto que sobreviva a um restart.**
O trabalho todo do M20 (G1-G7) deixou o **schema, a validação e a tela de exemplo** prontos —
mas as duas peças que faltam para um cliente real usar de verdade (escrita persistente ligada +
tela do lado do cliente) nunca foram construídas. Isso é anterior a decidir Casa de Bolos/MEI.

## 1. Duas trilhas novas, em paralelo com o resto

### Trilha A — Habilitar escrita real (prioridade máxima, bloqueia tudo)

Escopo: estender `RPC_ALLOWLIST` (hoje 7 comandos) para os 13 do contrato `M20-VISUAL-2.0`
(`party.document.add`, `catalog.item.fiscal.set` etc. já mapeados no M20-G3, mas nunca
liberados pra escrita), implementar de fato o modo `'persistent'` no seletor (hoje só existe
como erro), e — mais importante — testes adversariais de isolamento cross-tenant *antes* de
qualquer liberação (um comando executado pelo tenant A não pode nunca tocar dado do tenant B;
isso já é a política de todo o projeto, só precisa ser reprovado/aprovado formalmente pra este
gate específico). Estimativa: 1 a 2 dias úteis de trabalho técnico, maior parte em testes.

### Trilha B — Abrir o M05 real em `apps/portal` (o cliente loga aqui)

Não é reescrever nada do zero: a camada de serviço/validação/domínio do M20
(`br-documents.mjs`, os schemas zod, os commands do visual-persistence) é agnóstica de app —
pode ser reaproveitada. O trabalho aqui é: rota real `(portal)/cadastros` (hoje só existe o
card estático), escopada pela **membership do próprio cliente** (não por `is_platform_staff`),
reaproveitando os mesmos formulários elevados no M20-G6 com o `tenant_id` vindo da sessão do
cliente. Estimativa: 2 a 3 dias úteis (a maior parte do trabalho de tela já está feita — falta
o encanamento de tenant/rota/RLS do lado do portal).

**As duas trilhas são independentes uma da outra** e podem ser autorizadas e executadas de
ponta a ponta sem interrupção, no mesmo padrão dos gates M20 — mas juntas são o pré-requisito
real antes de qualquer cliente novo (Casa de Bolos, MEI) "ganhar acesso" de verdade.

## 2. Enquanto isso: o que pode andar em paralelo, sem depender das trilhas acima

Provisionamento (tenant + estabelecimento + usuário Auth + membership + convite) é feito
direto no Supabase (SQL/API), **não depende de nenhuma tela do app** — é exatamente o processo
já validado com a Mania de Modas no M18-G21/G22. Isso pode ser feito agora para os 2 clientes
novos, deixando tudo pronto pro dia em que as trilhas A/B destravarem a digitação real.

### 2.1 — Casa de Bolos (Eliana Souza Farias Alves)

- 1 tenant novo, 1 estabelecimento, CNPJ `26.223.863/0001-11`
- Vertical: `casa_de_bolos` — **já existe**, seedada desde o M20-G2 (`erp_business_verticals`),
  com atributo obrigatório `validade_dias`. Nenhum trabalho de schema novo aqui.
- **Pendente de você**: regime tributário (Simples Nacional é o mais comum pra confeitaria
  pequena, mas não foi informado — preciso confirmar antes de definir `tax_code_kind`
  CST/CSOSN) e e-mail da responsável (pra criar o usuário Auth + convite).

### 2.2 — MEI Aldo Augusto Ribeiro + MEI Eliane Aparecida Moreira Ribeiro

- **Recomendo 1 tenant, 2 estabelecimentos** (não 2 tenants separados) — é diferente do caso
  iGreen/Nipponflex (marcas de terceiro sem relação societária entre si). Aqui os dois MEIs já
  são operados juntos por decisão do próprio cliente ("gerenciados juntos"), e
  `erp_establishments` já foi desenhado exatamente pra isso: catálogo e clientes
  compartilhados, cada CNPJ com seus próprios documentos fiscais. O seletor de estabelecimento
  (M20-G4, já pronto) deixa trocar entre a loja do Aldo e a da Eliane mantendo o resto
  consolidado.
- Vertical: `celular_multi_cnpj` — **já existe** na lista de 14 aprovada, criada
  especificamente pra este padrão (celular/informática, multi-CNPJ).
- Regime: MEI segue Simples Nacional/regras próprias → `tax_code_kind = CSOSN` (já suportado).
- **Pendente de você**: confirmar que "1 tenant/2 estabelecimentos" reflete como o cliente quer
  ver o próprio negócio (ele vai perceber os dois CNPJs como "uma coisa só" com abas, ou
  precisa parecer duas contas separadas?), e-mails dos dois responsáveis, e nome de fantasia do
  tenant combinado (ex.: "Aldo & Eliane Assistência Técnica").

### 2.3 — Fato novo: regime "Normal" da Mania de Modas

Sem impacto de schema — `erp_item_fiscal_data.tax_code_kind` já suporta `'CST'` desde o M20-G1
(o enum sempre teve os dois regimes, CST e CSOSN, porque o motor fiscal do M13 já precisava dos
dois). O que muda é só a **digitação**: cada produto da Mania de Modas usa código CST de 2
dígitos (`00,10,20,30,40,41,50,51,60,70,90`), não CSOSN de 3 dígitos. Isso já está validado e
travado por `zod` em `catalog/validations.ts` — só passa a valer no dia em que a Trilha A
destravar escrita real.

## 3. "Quatro páginas" — o que isso é de verdade na arquitetura

Não são 4 telas HTML diferentes: é a **mesma** tela de Cadastros/Catálogo (M20-G6), reaberta 4
vezes com contexto diferente — Mania de Modas (tenant 1), Casa de Bolos (tenant 2), loja do
Aldo e loja da Eliane (tenant 3, 2 estabelecimentos, trocados pelo seletor). Tecnicamente isso
já existe assim que a Trilha B abrir o M05 real do portal — cada cliente loga na própria conta
e vê só o próprio tenant, sem nenhuma tela nova por cliente.

## 4. Preparação para os 3 clientes futuros — o que falta em cada um

| Cliente futuro | Vertical já existe? | Gap real |
|---|---|---|
| Material de construção | ✅ `material_construcao` (M20-G2) | Nenhum — só provisionamento quando chegar. |
| Food truck (lanches, tamanhos diferentes) | ❌ Não está nos 14 seedados | Precisa de vertical nova (ou reaproveitar `restaurante` com atributo "tamanho" via EAV, mesmo padrão já usado em `moda`) — trabalho pequeno, 1 migration de seed. |
| Restaurante 5 unidades (delivery + distribuição interna) | Parcial — `restaurante` existe, mas só como conceito de segmento | **Maior gap real do lote**: hoje não existe conceito de transferência de estoque entre estabelecimentos nem fluxo de delivery (endereço de entrega, status, taxa). Isso é schema novo, maior que os outros — mereceria seu próprio gate depois que as Trilhas A/B fecharem. |

## 5. Ordem recomendada (resumo executável)

1. **Trilha A** — habilitar escrita real (bloqueia tudo, prioridade máxima)
2. **Trilha B** — abrir M05 real no `apps/portal` (pode começar em paralelo à Trilha A)
3. Provisionar Casa de Bolos e MEI (Aldo+Eliane) no Supabase — pode começar **agora**, não
   depende de A/B, mas os responsáveis só conseguem logar e ver algo depois que A fechar
4. Confirmar regime da Mania de Modas (Normal/CST) na primeira digitação real de produto
5. Seed da vertical `food_truck` (ou atributo em `restaurante`) — pequeno, quando o cliente
   estiver mais perto
6. Gate novo de transferência entre estabelecimentos + delivery — planejar depois de A/B,
   antes do restaurante de 5 unidades chegar

## 6. Perguntas que preciso de você antes de executar

1. Regime tributário da Casa de Bolos (Simples Nacional, presumo, mas confirma)
2. E-mail de Eliana (Casa de Bolos), Aldo e Eliane (MEI) — pra criar os acessos
3. MEI: "1 tenant/2 estabelecimentos" é como o cliente entende o próprio negócio, ou ele quer
   ver como duas contas separadas mesmo sendo gerenciadas juntas por você?
4. Autorizo a Trilha A (escrita real) e a Trilha B (M05 do portal) para execução autônoma de
   ponta a ponta, no mesmo padrão dos gates M20 (relatório + validação local + checkpoint,
   sem tocar produção)?
