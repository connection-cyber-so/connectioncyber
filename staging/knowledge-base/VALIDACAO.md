# M22 — Biblioteca Técnica — Evidências 0.1.2

Data: 13/09/2026. Base: b7f0dde5416bfff4186b6f50f93e877359ca3461.

## Etapa 1 — Inventário

Três diretórios lidos. Cópia principal divergente e alterada; cópia staging alinhada à referência local origin/staging; validação em detached HEAD. Nenhum fetch foi feito para inferir estado remoto. Arquivos preexistentes não rastreados preservados. Apenas a cópia staging foi alterada.

## Etapa 2 — Implementação

Migration aditiva 0043, sete tabelas com RLS, RPC transacional, bucket privado, UI do portal, serviços, adaptador Gemini, permissões e assinatura com negação por padrão. Arquivos, snapshots e evidências ficam associados às revisões.

## Etapa 3 — Testes e análise estática

- Portal: 131/131 testes aprovados, incluindo cinco novos testes de contrato.
- TypeScript: tsc --noEmit --incremental false aprovado.
- Lint: sem erros ou avisos ESLint.
- Banco: 41 asserções funcionais/adversariais aprovadas em PGlite, usando helpers de autorização originais e schema pré-requisito sintético. Migration executada integralmente no laboratório.
- Build: Next.js 15.5.21 compilado, rotas /biblioteca e /api/knowledge-base presentes. Build final completo aprovado após os ajustes, incluindo a rota protegida de snapshots históricos.
- Documentação: geração e --check aprovados; manifesto normaliza quebras de linha para Windows/Linux.

## Homologação publicada

Em 14/09/2026, a branch `staging` foi publicada em `origin/staging`, passou integralmente pelo workflow `Quality gates` e foi implantada no Vercel Preview. A flag `KNOWLEDGE_BASE_ENABLED=true` e o host central foram limitados ao Preview da branch staging.

A jornada real no Supabase staging confirmou M0, classificação, M1, aplicação, M2, destino GitHub, M3 e liberação M4 por segundo curador. O item liberado terminou em revisão 9 e score 92/100. Um arquivo sintético foi enviado e baixado pelo Storage HTTP; o SHA256 `8310e95f21add427464f8bc92deea9e5154eb0b6cb5d662ffc11fb1b3117f4e4` foi preservado. O assinante leu o item liberado, favoritou, avaliou com nota 5 e recebeu download autorizado.

No navegador publicado foram confirmados login, contexto do tenant, catálogo, busca/filtros, página do item, classificação, arquivos, favorito, avaliação, auditoria, download, painel de curadoria e MFA/AAL2. As credenciais usadas foram rotacionadas ao término e permanecem protegidas por Windows DPAPI.

O adaptador Gemini foi acionado somente com conteúdo sintético e consentimento explícito. O modelo foi atualizado de `gemini-2.5-flash`, que retornava 404, para `gemini-3.8-flash`. O provedor retornou 503 nas tentativas finais; o código passou a repetir 429/5xx e timeouts com limites. A indisponibilidade não afeta o fluxo manual nem libera conteúdo automaticamente.

## Limites da evidência

Em 14/09/2026, a migration 0043 foi aplicada somente ao Supabase staging `ozvylnaipubrmaadikvk`, depois de preflight, dry-run e dump local do esquema. O histórico remoto ficou alinhado de 0001 a 0043. Foram confirmados bucket privado, 12 policies, um tenant sintético, três memberships, três entitlements ativos e dois grants `knowledge.manage`.

Foram criadas três identidades sintéticas sem envio de e-mail: dois curadores e um assinante. Em sessões reais do Supabase Auth, cada curador ficou com `access=false/manage=false` em AAL1 e `access=true/manage=true` após cadastro e verificação TOTP em AAL2. O assinante ficou com `access=true/manage=false` em AAL1. As memberships e assinaturas sintéticas expiram em 21/09/2026. As credenciais foram protegidas localmente com Windows DPAPI e não aparecem neste documento.

Não houve alteração de pagamentos, produção ou dados reais. A evidência cobre staging e Preview; não autoriza promoção automática para produção. A IA externa permaneceu indisponível por resposta 503 do provedor, com fallback manual validado.

Na entrega local inicial, o Docker daemon estava indisponível e Node 22.23.2 foi instalado isoladamente na pasta de trabalho. Em 14/09/2026 o Docker estava disponível e o dump remoto foi concluído. O Node global permaneceu inalterado.

## Riscos residuais para produção

- Integrar entitlement comercial somente após idempotência e reconciliação com Mercado Pago; as três assinaturas atuais são fixtures temporárias.
- Monitorar disponibilidade/quota do Gemini e repetir o smoke test quando o provedor normalizar.
- Inspeção de malware é responsabilidade do operador, com evidência antes de M4.
- Usar 3 MiB por upload; mídia maior por referência. O histórico da interface é limitado aos registros mais recentes, mantendo todos no banco.
- URLs assinadas têm janela de validade de 60 segundos. Métrica de download representa autorização emitida.

Resultado: módulo, fronteira de autorização, portal, Storage e jornada M0–M4 homologados no staging/Preview. Não declarar M4 de produção concluído.
