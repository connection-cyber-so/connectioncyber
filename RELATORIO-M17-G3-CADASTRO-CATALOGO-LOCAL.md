# M17-G3 — cadastro e catálogo com repositórios locais

Data: 31/08/2026

## Entrega

- Aplicação local conecta `party.create` e `catalog.item.create` à fronteira server-side M17-G2.
- A aplicação recebe somente host e comando; autorização não pode ser fornecida pelo navegador.
- Unidade de trabalho mantém cadastro, catálogo e inbox idempotente em uma única transação de memória.
- Repositórios armazenam e consultam registros isolados por tenant.
- IDs são determinísticos e derivados de tenant, comando e request ID sintéticos.

## Controles comprovados

- tenant e ator gravados vêm exclusivamente da autorização server-side;
- outro tenant não lê cadastros nem itens;
- replay não duplica recursos;
- mesma chave com payload divergente é recusada;
- nomes e códigos duplicados são recusados por tenant;
- falha após escrita restaura repositório e inbox;
- permissão ou capacidade ausente bloqueia antes do repositório;
- tipos, papéis e regras de estoque do item são validados;
- nomes empresariais, itens e descrições precisam declarar escopo sintético.

## Evidências

- Testes do pacote: 68/68 aprovados com Node.js 22.23.2.
- Simulação: `M17_G3_LOCAL_MASTER_DATA_OK`.
- Resultado: um cadastro, um item, dois eventos de autorização e dois comandos idempotentes.
- Plataforma: 32/32 testes, TypeScript, ESLint e build aprovados.
- Persistência remota, Supabase, rede e produção não acessados.

## Limite desta etapa

Cadastro e catálogo foram integrados à camada de aplicação usando repositórios locais. A interface atual e os adaptadores Supabase ainda não foram substituídos; isso permanece para gates posteriores.

Marcador: `M17_G3_LOCAL_MASTER_DATA_OK`

Próxima etapa automática: M17-G4 — integrar estoque, PDV e caixa em uma unidade de trabalho local idempotente, usando somente dados sintéticos.
