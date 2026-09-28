# M18-G11 — seleção fail-closed do transporte visual

Data: 01/09/2026

Estado: aprovado localmente

Marcador: `M18_G11_FAIL_CLOSED_VISUAL_TRANSPORT_LOCAL_OK`

## Resultado

- Fachada server-side única criada para as leituras, comandos e preparações consumidos pelas telas.
- Dashboard, cadastros, catálogo, estoque, PDV, caixa e financeiro usam a fachada selecionada.
- O modo `synthetic` seleciona exclusivamente o dublê local em memória.
- O modo `persistent` falha com `PERSISTENT_TRANSPORT_DISABLED` antes de tocar sua dependência.
- Modo ausente, desconhecido ou dublê ausente também falha fechado.

## Segurança

- A seleção não lê variáveis de ambiente.
- A fachada não cria cliente Supabase e não importa a composição persistente.
- O navegador não escolhe transporte nem tenant.
- A ativação remota permanece constante e explicitamente desabilitada.

## Evidências

- Node.js `22.23.2`.
- Plataforma: `86/86` testes.
- Contrato visual persistente: `50/50` testes.
- Adaptador persistente: `44/44` testes.
- TypeScript, ESLint e build Next.js: aprovados.

Nenhum serviço remoto foi acessado e nenhum dado foi criado ou alterado.
