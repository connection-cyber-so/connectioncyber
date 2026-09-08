# M21-G3 — corrige o layout real de Cadastros pro padrão já validado

Data: 08/09/2026

## O que estava errado

A tela real de `/cadastros` em `apps/portal` (M21-G2) usou o design system genérico
do portal (`.content-heading`, `.form-stack`, `.alert`) em vez do layout que foi
iterado e confirmado com o usuário em 5 rodadas de PDF sobre `cadastros-tela-unica.html`
(header-bar com contador, campos agrupados em `grp/row/field`, bordas `#0A1F33`, painel
lateral com abas de Documentos/Contatos/Endereços). Usuário identificou a divergência ao
ver o print da tela em produção.

## Correção

- `apps/portal/src/app/(portal)/cadastros/cadastros.css` (novo): mesma paleta/classes do
  layout validado, namespaced sob `.cc-classic` pra não vazar no resto do portal (que tem
  seu próprio design system).
- `page.tsx` reconstruída: header-bar (eyebrow + título + pill de contagem), counter-row
  (Cadastros/Ativos), formulário de criação com `grp/row/field`, lista de cadastros abaixo,
  e — quando um cadastro é selecionado (`?party=<id>`) — painel lateral com abas
  Documentos/Contatos/Endereços, cada uma com lista + mini-formulário.
- Campos só decorativos do mockup original (cartão de crédito, certificado A1, TEF,
  histórico) **não entraram** — o mockup já os marcava como "cadastro de exemplo"; a tela
  real só tem campo que grava em algum lugar de verdade.
- **3 rotas novas** (`novo-documento`, `novo-contato`, `novo-endereco`), mesmo idioma exato
  de `nova-pessoa/route.ts`, escrevendo pelos comandos reais do M21-G1
  (`party.document.add`, `party.contact.add`, `party.address.add`).
- Máscara/validação de CPF-CNPJ (mod-11) e busca de CEP (ViaCEP) reaproveitadas do mockup,
  como JS puro via `addEventListener` — **não** como atributo inline (`onInput="..."`), que
  foi um bug real que cometi na primeira tentativa (JSX não aceita string como handler de
  evento; corrigido antes de qualquer teste ou commit).

## Validação

- `npx tsc --noEmit --incremental false`: 0 erros.
- `npx tsx --test`: **122/122** (105 anteriores + 17 novos, `m21-g3-cadastros-layout-validado.test.ts`).
- `npx eslint`: 0 avisos.
- `next build` não executado (mesma cautela dos gates anteriores).

## Pendências desta fatia

Mesmas do M21-G2: Catálogo (produto) e edição de dados da empresa ainda não têm tela real;
"Pesquisar/Imprimir/Vendas/Extrato/Orçamentos" do header-bar do mockup ficaram de fora
(sem comando real por trás ainda).
