## M22 — Biblioteca Técnica — homologação end-to-end 0.1.2

Atualização: 14/09/2026. Estado: módulo ativado e homologado no Supabase staging e Vercel Preview; produção preservada.

Escopo: portal /biblioteca, conteúdo reutilizável para assinantes por tenant, gates de conteúdo M0–M4, classificação manual e adaptador Gemini, score, sugestão GitHub, arquivos privados, busca, favoritos, avaliações, versões e curadoria.

Evidência: 131 testes do portal; 41 asserções PostgreSQL/RLS; tipos, lint, build e quality gates remotos aprovados. No Supabase staging, a migration 0043 foi aplicada, o bucket privado e 12 policies foram confirmados e três identidades sintéticas foram autenticadas. Os dois curadores ficaram sem acesso administrativo em AAL1 e obtiveram access/manage somente em AAL2; o assinante obteve access sem manage em AAL1. A jornada real M0–M4, revisão independente, Storage HTTP, hash, favorito, avaliação, download e interface publicada foram validados.

Entrega: migration aditiva 0043 aplicada exclusivamente no projeto ozvylnaipubrmaadikvk; tenant sintético isolado, três memberships e três entitlements ativos até 21/09/2026; knowledge.manage atribuído somente aos dois curadores com TOTP verificado. KNOWLEDGE_BASE_ENABLED=true somente no Preview da branch staging. Produção, Mercado Pago e dados reais não foram alterados.

Resultado: homologação M0–M4 concluída no Preview. O adaptador Gemini, consentimento e auditoria foram exercitados; o modelo descontinuado foi atualizado e falhas 429/5xx/timeouts agora possuem repetição segura. O provedor respondeu 503 mesmo após as tentativas finais, portanto a classificação manual permanece operacional e a IA externa segue como dependência degradável. Promoção, produção e integração comercial exigem gates separados. Rollback não destrutivo documentado.
