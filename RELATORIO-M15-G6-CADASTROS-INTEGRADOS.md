# M15-G6 — cadastros visuais integrados ao PDV

Data: 30/08/2026  
Ambiente: `connectioncyber-staging`  
Escopo remoto: nenhum

## Implementação

- Cadastro visual de cliente sintético com nome, e-mail `.invalid` e tipo.
- Cadastro visual de produto sintético com código `SYN-*`, preço e estoque.
- Estado compartilhado pelo dashboard durante a sessão do navegador.
- Clientes e produtos recém-cadastrados disponibilizados imediatamente no PDV.
- Cliente selecionável na venda e identificado no comprovante sintético.
- Nenhum `fetch`, Supabase, armazenamento local ou persistência remota.

## Validação

- Testes automatizados: `37/37` aprovados.
- TypeScript: aprovado.
- ESLint: aprovado.
- Regras específicas: e-mail reservado `.invalid`, código sintético automático, estoque inteiro e preço positivo.
- Runtime oficial: Node.js `22.23.2`, distribuição portátil oficial com SHA-256 validado.
- Build Next.js: aprovado; rota `/demo` gerada estaticamente com 6,11 kB.
- Desktop: cliente e produto cadastrados, selecionados no PDV e venda sintética concluída.
- Celular: viewport 390 × 844, formulário visível e `scrollWidth=375`, sem rolagem horizontal.

## Decisão

`M15_G6_VISUAL_INTEGRATION_OK`. Implementação, build e jornada visual aprovados no runtime oficial Node.js 22; nenhum serviço remoto ou produção foi acessado.
