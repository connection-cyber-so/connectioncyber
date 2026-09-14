## M22 — Biblioteca Técnica — homologação de banco 0.1.1

Atualização: 14/09/2026. Estado: migration e autorização validadas no Supabase staging; ativação do portal pendente.

Escopo: portal /biblioteca, conteúdo reutilizável para assinantes por tenant, gates de conteúdo M0–M4, classificação manual e adaptador Gemini, score, sugestão GitHub, arquivos privados, busca, favoritos, avaliações, versões e curadoria.

Evidência: 131 testes do portal; 41 asserções PostgreSQL/RLS; tipos, lint e build locais aprovados. No Supabase staging, a migration 0043 foi aplicada, o bucket privado e 12 policies foram confirmados e três identidades sintéticas foram autenticadas. Os dois curadores ficaram sem acesso administrativo em AAL1 e obtiveram access/manage somente em AAL2; o assinante obteve access sem manage em AAL1.

Entrega: migration aditiva 0043 aplicada exclusivamente no projeto ozvylnaipubrmaadikvk; tenant sintético isolado, três memberships e três entitlements ativos até 21/09/2026; knowledge.manage atribuído somente aos dois curadores com TOTP verificado. Feature flag desligada por padrão. Produção, Mercado Pago e dados reais não foram alterados.

Próximo gate: ativar o portal somente no Preview da branch staging e homologar navegador, gates M0–M4, Storage HTTP, URL assinada e Gemini. Promoção, produção e integração comercial exigem gates separados. Rollback não destrutivo documentado.
