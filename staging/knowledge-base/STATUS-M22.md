## M22 — Biblioteca Técnica — entrega local 0.1.0

Atualização: 13/09/2026. Estado: Validado localmente; ativação em staging pendente.

Escopo: portal /biblioteca, conteúdo reutilizável para assinantes por tenant, gates de conteúdo M0–M4, classificação manual e adaptador Gemini, score, sugestão GitHub, arquivos privados, busca, favoritos, avaliações, versões e curadoria.

Evidência: 131 testes do portal; 41 asserções PostgreSQL/RLS; tipos, lint e build locais aprovados. Limites: laboratório PGlite com pré-requisitos sintéticos, sem Supabase completo, Storage HTTP, IA real ou sessão de navegador homologada.

Entrega: migration aditiva 0043; assinatura e knowledge.manage não concedidos automaticamente; feature flag desligada por padrão. Documentação em staging/knowledge-base e relatórios RELATORIO-M22-G0 até G4, gerados em MD/HTML com manifesto de código. Produção e remotes não alterados.

Próximo gate: homologar Supabase/Storage/portal em staging com assinatura verificada, curadores independentes e MFA; configurar IA se desejada. Promoção e deploy exigem autorização separada. Rollback não destrutivo documentado.
