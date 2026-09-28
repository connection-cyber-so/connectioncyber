# M20-G6 — cadastro real elevado para "tela de uso" + decisão de onboarding sem migração

Data: 07/09/2026

## Gatilho

Usuário confirmou: **não existe backup real do sistema legado da Mania de Modas** — só os 28
prints do SICNET já usados como referência visual no M20-G0. Decisão: tratar Mania de Modas
como **cliente novo, cadastro do zero**, não como migração.

## O que isso muda no roteiro

- **`§9. Processo de migração por cliente`** (`STATUS-MESTRE-DESENVOLVIMENTO.md`) — os 11 passos
  (receber backup, restaurar isolado, extrair, transformar, carregar, reconciliar, aceite,
  corte) **não se aplicam a este cliente**: não há origem pra extrair. Passa a valer para
  qualquer *outro* cliente que chegue com backup real.
- **M14 (engenharia reversa/importador)** — fica sem execução para Mania de Modas: não há nada
  para importar. Permanece como capacidade genérica do produto (útil pro próximo cliente que
  tiver backup de verdade), fundação já concluída em staging desde 29/08/2026.
- **M15 (piloto Mania de Modas)** — a "ativação real do módulo" deixa de depender do importador
  e passa a depender só de: (1) migrations 0037/0038/0039 aplicadas em staging (pendente — ver
  bloqueio abaixo); (2) telas reais de cadastro em qualidade de uso, não esqueleto de aceite de
  gate (este gate, G6); (3) a própria Mania de Modas (ou a equipe ConnectionCyber em nome dela)
  digitando os dados reais direto nas telas — não existe outro caminho de entrada de dado sem
  importador.

## O que foi feito neste gate (código, sem dado real, sem tocar staging)

Achado do M20-G0 (07/09/2026): *"formulários da UI (`PartyForm.tsx`, `CatalogForms.tsx`) são
esqueleto de aceite de gate, não tela de uso"*. Este gate resolve isso nos dois formulários
principais de cadastro:

1. **`src/domain/br-documents.mjs`** (novo) — CPF/CNPJ com dígito verificador real (mod-11),
   não só contagem de dígitos; máscara progressiva de CPF/CNPJ/telefone. Módulo `.mjs` puro
   (mesmo padrão de `src/domain/redirect.mjs`), testável direto com `node --test` sem loader de
   TypeScript. 13 testes novos (`tests/br-documents.test.mjs`), todos passando.
2. **`PartyForm.tsx`** — tipo (PF/PJ) troca o rótulo e a máscara do documento ao vivo; erro de
   dígito verificador aparece antes de enviar, não só depois do servidor rejeitar.
3. **`parties/validations.ts`** — o mesmo dígito verificador agora também roda no servidor
   (`isValidTaxId`), que é quem de fato decide — o client é conforto de digitação, nunca a
   fonte da verdade.
4. **`PartyDetailPanel.tsx`** — aba Contatos: telefone/celular/whatsapp ganham máscara ao vivo.
   Aba Endereços: CEP busca automaticamente logradouro/bairro/cidade/UF via ViaCEP (mesma API
   pública já usada nos mockups desta sessão); usuário só confere e completa número/complemento.
5. **`CatalogForms.tsx`** (`ItemForm`) — ao escolher tipo Serviço/Taxa/Vale, "Controla estoque"
   desliga e trava na hora (a regra já existia no zod; agora também aparece na tela, não só
   depois do envio).

Nenhuma migration, RLS, comando ou tabela mudou — é só qualidade da tela sobre o que o M20-G1/G3
já tinha construído e testado.

## Validação

- `npx tsc --noEmit`: 0 erros.
- `node --test tests/*.test.mjs`: **192/192** (13 novos de `br-documents`, 179 pré-existentes
  intactos — nenhuma regressão nas 6 asserções do M20-G3/G4 que checam `PartyDetailPanel.tsx`/
  `ItemDetailPanel.tsx` por substring).
- `npx eslint` nos 5 arquivos alterados: 0 avisos/erros.
- `npx next build` **não executado nesta sessão** — havia processos `node` ativos na máquina e,
  duas vezes nesta mesma conversa, rodar `next build` com um `next dev` ao vivo na mesma pasta
  corrompeu o `.next` do usuário. Recomendo rodar `npm run build` manualmente antes do próximo
  deploy, ou confirmar que o dev server está parado para eu rodar aqui.

## Bloqueio que continua de pé (não é deste gate, é anterior)

As migrations `0037`/`0038`/`0039` (dado fiscal, verticais de negócio, IBS/CBS) só foram
validadas em **Docker local descartável** — nunca aplicadas no Supabase de staging real
(`ozvylnaipubrmaadikvk`). Confirmado de novo agora: o conector MCP do Supabase deste ambiente
está preso a um projeto errado (`portal-teologico-os`, org `oeqlxqppsaavipjtfvdb`) — mesma
classe de problema já registrada para o MCP do Vercel nesta máquina — e `.env.local` não tem
`service_role key`. **Sem isso, nem eu aplico as três migrations em staging, nem valido as
telas de fiscal/comercial/vertical contra o tenant real da Mania de Modas.**

Isso é o próximo obstáculo real pro piloto — não uma decisão, um problema de credencial/conexão
que só o usuário resolve (reconectar o MCP certo, ou me passar a `service_role key` de staging,
ou aplicar as três migrations manualmente pelo painel/CLI do Supabase).

## Próxima ação autorizável

Nenhuma automática — depende do usuário resolver o acesso ao Supabase de staging real (acima).
Depois disso: aplicar 0037/0038/0039 em staging, confirmar a vertical "moda" atribuída ao
estabelecimento da Mania de Modas (M20-G2), e então a própria digitação real dos primeiros
clientes/produtos pode começar pelas telas já elevadas neste gate.
