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
- Build e ensaio visual: pendentes de repetição com Node.js 22; a máquina está expondo Node.js 26 e o projeto bloqueia versões diferentes de 22.

## Decisão

Implementação local concluída e validada estaticamente. O encerramento do gate visual permanece bloqueado até executar o runtime oficial Node.js 22; nenhum serviço remoto ou produção foi acessado.
