# Governança de execução automática

**Vigência:** 01/09/2026

## Comunicação durante o processamento

- Exibir somente `GATE_EM_EXECUCAO`, bloqueio que exija decisão e `GATE_CONCLUIDO`.
- Suprimir narração de comandos, tentativas intermediárias e resultados repetitivos da conversa.
- Continuar automaticamente em implementação, testes, correções, documentação e validações autorizadas.
- Solicitar intervenção somente para credenciais protegidas, decisões materiais, escrita remota, identidade real, produção ou ação destrutiva.

## Registro técnico obrigatório

- Cada gate mantém relatório técnico próprio no repositório.
- `STATUS-MESTRE-DESENVOLVIMENTO.md` e `STATUS-MESTRE-DESENVOLVIMENTO.html` permanecem equivalentes e atualizados.
- O relatório registra escopo, alterações, testes, hashes ou marcadores aplicáveis, ambiente, riscos, decisão e próximo gate.
- A resposta final resume gate, resultado, testes, commit, efeitos remotos, relatório e próximo gate.

## Protocolo Staging-First (versionamento e deploy)

**Vigência desta seção:** 04/09/2026 — adotado a partir de `Protocolo Staging-First.txt`
(fornecido pelo usuário), formalizado em `PARECER-TECNICO-PROTOCOLO-STAGING-FIRST.md`.

- Alterar código somente em `connectioncyber-staging`; `main` (produção) nunca é editado
  direto — já era a regra, agora nomeada.
- Antes de todo commit: testes locais do(s) app(s)/pacote(s) afetado(s) + `npx tsc --noEmit`
  (ou `npm run type-check`) limpos. Corrigir antes de prosseguir, nunca commitar com tipo quebrado.
- Comando outward-facing (push, deploy, escrita remota) sempre anunciado antes de executar.
- Nunca fabricar resultado: verificar banco, build, terminal e logs reais antes de reportar
  qualquer estado como concluído — inclusive "deploy concluído" (ver seção 2 do parecer: build
  bem-sucedido na Vercel não é o mesmo fato que promovido ao domínio real; confirmar os dois).
- Promoção `staging` → `main`: Commit → Push → Pull Request → Revisão → Merge → **Backup de
  produção** → Deploy, nesta ordem, sempre com autorização explícita separada (já exigida por
  este documento) — o protocolo só torna o checklist concreto.
- **M-Gate Versionamento**, obrigatório em toda alteração (checklist completo no parecer):
  staging atualizado, testes locais aprovados, tipos validados, PR revisado (só promoção),
  backup realizado (só promoção), deploy autorizado **e confirmado no domínio real**,
  monitoramento pós-deploy.

## Memória operacional

Este arquivo é a regra persistente do projeto. Em caso de compactação do contexto ou nova sessão, ele deve ser consultado antes de continuar a sequência de gates.
