# Parecer Técnico — Protocolo Staging-First (versionamento, deploy e governança)

Data: 04/09/2026 · Origem: arquivo `Protocolo Staging-First.txt` fornecido pelo usuário
(`DadosConnectionCyber/menssagens/`) · Motivado por um achado concreto durante o fechamento do
M18-G22 (seção 2).

## 1. Do que se trata

O arquivo fornecido propõe um protocolo institucional de cinco partes para regular como código
é desenvolvido, testado, versionado e promovido a produção: (1) separação física staging/produção,
(2) um fluxo obrigatório de cinco passos por alteração, (3) três regras complementares de
operação, (4) integração à documentação institucional, e (5) um gate de governança dedicado
(`M-Gate Versionamento`). Este parecer avalia o protocolo contra o estado real deste repositório,
decide o que já está coberto, o que é novo, e formaliza a adoção na governança viva do projeto
(`GOVERNANCA-EXECUCAO-AUTOMATICA.md`).

## 2. Por que isto chegou agora — o achado que motivou a análise

Ao validar em campo a tela de MFA/TOTP implementada e publicada nesta mesma sessão (commit
`46bacff`, M18-G22), o usuário reportou não ver o QR code esperado. Diagnóstico feito ao vivo:

| Verificação | Resultado |
|---|---|
| Testes locais (`apps/portal`) | 86/86 ✅ |
| `type-check` / `lint` / `next build` locais | limpos ✅ |
| CI "Quality gates" no GitHub para o commit `46bacff` | 8/8 jobs ✅ |
| Status de deploy do GitHub para `46bacff` (Vercel – connectioncyber-portal) | `success`, concluído 22:02:09 UTC ✅ |
| `curl -I https://portal.connectioncyber.com.br/configuracoes/seguranca` (sem sessão) | **`404 Not Found`**, com `Age` de cache batendo com um `Last-Modified` de **13:20 UTC** — várias horas antes do deploy do commit `46bacff` ❌ |

**Conclusão**: o pipeline (testes → CI → build → deploy) funcionou de ponta a ponta e a Vercel
confirmou o deploy como bem-sucedido — mas o domínio próprio (`portal.connectioncyber.com.br`)
continuou servindo uma build antiga, sem a rota nova. Ou seja: **"deploy concluído com sucesso"
não é o mesmo fato que "está no ar no domínio do cliente"** — existe uma etapa de promoção/alias
no meio que este projeto nunca verificou explicitamente até hoje. Isto não é um bug no código do
MFA; é exatamente a lacuna de processo que o Protocolo Staging-First propõe fechar (Passo 5 —
"Produção só é tocada no deploy", e o checklist do M-Gate Versionamento — "deploy autorizado").
Sem acesso de API à Vercel neste ambiente (o conector MCP disponível retornou `403 Forbidden` —
token sem escopo para o time `connectioncyberso`), a confirmação final de qual build está
promovida ao domínio depende de checagem manual no painel da Vercel pelo usuário.

## 3. Mapeamento do protocolo contra o estado real do repositório

| Parte do protocolo | Já coberto? | Como |
|---|---|---|
| **1. Duas pastas fixas staging/produção** | ✅ Já existe | `CLAUDE.md` §"Repo identity": este clone é `connectioncyber-staging`, sempre irmão do clone `main` (produção); nunca aninhado. |
| **2. Passo 1 — alterar só em staging** | ✅ Já existe | Toda a sessão trabalha exclusivamente na branch/clone `staging`; produção exige autorização separada (`GOVERNANCA-EXECUCAO-AUTOMATICA.md`). |
| **2. Passo 2 — testar localmente antes do commit** | ✅ Já existe, reforçado | `npm test`/`npm run dev` por app; nesta sessão, 86/86 testes locais antes de qualquer commit do MFA. |
| **2. Passo 3 — `npx tsc --noEmit` antes do commit** | 🔶 Praticado ad hoc → **formalizado agora** | Já rodado manualmente nas últimas gates; passa a ser regra explícita em `GOVERNANCA-EXECUCAO-AUTOMATICA.md` (seção 4 deste documento). |
| **2. Passo 4 — Commit→Push→PR→Revisão→Merge→Backup→Deploy** | 🔶 Parcial, com uma decisão de calibragem | Ver seção 3.1 abaixo — este fluxo completo se aplica à **promoção staging→produção** (`main`), que já exige autorização explícita separada neste projeto; dentro de `staging`, o fluxo continua commit→push direto após testes locais, como já praticado (equivalente ao ambiente "exclusivo de desenvolvimento" do próprio protocolo, item 1). |
| **2. Passo 5 — produção só tocada no deploy** | ✅ Já existe | Nenhuma edição ou teste acontece direto em produção; e o achado da seção 2 mostra exatamente por que isto importa também do lado da *promoção*, não só da edição. |
| **3. Regra 1 — aviso antes, comando depois** | 🔶 Praticado, agora explícito | Ações que push/deploy/gravam remoto já são anunciadas antes de executar nesta sessão; formalizado como regra permanente. |
| **3. Regra 2 — nunca fabricar dados** | ✅ Já existe, e é o que resolveu a seção 2 | `GOVERNANCA-EXECUCAO-AUTOMATICA.md` já exige registro técnico verificado; o diagnóstico da seção 2 é um exemplo direto desta regra em ação (checar CI, deploy status e a URL real antes de declarar o portão fechado). |
| **3. Regra 3 — comunicação em PT-BR** | ✅ Já existe | Memória operacional do usuário (`respond-in-portuguese`) e prática já consolidada em todos os relatórios do repositório. |
| **4. Integrar à documentação institucional** | ✅ Feito por este parecer | `GOVERNANCA-EXECUCAO-AUTOMATICA.md` atualizado (seção 4 abaixo); este parecer é o registro técnico formal. |
| **5. M-Gate Versionamento** | ✅ Criado por este parecer | Seção 5 abaixo. |

### 3.1 Decisão de calibragem — onde o fluxo Commit→PR→Merge→Backup→Deploy se aplica

O protocolo, lido literalmente, pediria Pull Request e revisão para toda alteração — inclusive
dentro do próprio ambiente de desenvolvimento. Isso contradiria a premissa 1 do próprio
protocolo (`staging` = "ambiente exclusivo de desenvolvimento", onde alterar é o uso normal) e
não reflete como este projeto realmente opera (desenvolvimento solo, sem um segundo revisor
disponível por commit). A leitura adotada, e registrada aqui para não ser reinterpretada
silenciosamente depois:

- **Dentro de `staging`** (este repositório): commit → push direto, sempre precedido de teste
  local + `tsc --noEmit` limpos — o que já era a prática e agora é regra explícita.
- **Na promoção `staging` → `main` (produção real)**: o fluxo completo do protocolo se aplica —
  Pull Request, revisão, **backup de produção antes de qualquer merge**, e só então deploy. Isto
  não muda nada na prática atual porque este projeto **nunca promoveu nada a produção ainda**
  (toda promoção já exigia "autorização e checklist separados" por `CLAUDE.md`) — o protocolo só
  torna esse checklist concreto e nomeado, em vez de implícito.

## 4. Alteração aplicada em `GOVERNANCA-EXECUCAO-AUTOMATICA.md`

Nova seção "Protocolo Staging-First (versionamento e deploy)" adicionada ao arquivo, cobrindo:
regra de `tsc --noEmit` obrigatório antes de commit, regra de aviso antes de comando
outward-facing, e o checklist do M-Gate Versionamento (seção 5). O arquivo continua sendo a
regra persistente consultada no início de toda sessão — a partir de agora inclui este protocolo.

## 5. M-Gate Versionamento — checklist obrigatório

Aplicado a partir de agora em toda alteração de código deste repositório, e obrigatório antes de
qualquer promoção `staging` → `main`:

1. ☐ `staging` atualizado (working copy corresponde ao que será testado/commitado).
2. ☐ Testes locais aprovados (`npm test` do(s) app(s)/pacote(s) afetado(s)).
3. ☐ Tipos validados (`npx tsc --noEmit` ou `npm run type-check` limpo).
4. ☐ *(Só na promoção a produção)* PR revisado.
5. ☐ *(Só na promoção a produção)* Backup de produção realizado.
6. ☐ Deploy autorizado — **e confirmado como promovido ao domínio real**, não só "build
   concluído" (ver achado da seção 2: as duas coisas não são a mesma verificação).
7. ☐ Monitoramento pós-deploy contínuo — nesta sessão, isto significa reconferir o comportamento
   real na URL pública, não só o status do CI/Vercel.

## 6. Recomendação e próximo passo imediato

1. **Confirmar manualmente no painel da Vercel** (projeto `connectioncyber-portal`, time
   `connectioncyberso`) se o deployment do commit `46bacff` está marcado como o deployment de
   Produção e promovido ao domínio `portal.connectioncyber.com.br` — este ambiente não tem
   permissão de API para o time correto (`403 Forbidden`) e não pode confirmar isso sozinho.
2. Se não estiver promovido: promover manualmente (ou reexecutar o redeploy apontando pro
   commit certo) pelo próprio painel.
3. Depois de promovido, reconfirmar com o mesmo teste usado no diagnóstico —
   `curl -I https://portal.connectioncyber.com.br/configuracoes/seguranca` deve responder
   redirecionamento (não `404`) mesmo sem sessão — antes de pedir pro piloto tentar de novo.
4. Só então repetir o teste real com o usuário-piloto (item 6 do checklist do M-Gate
   Versionamento).
