# Knowledge Base validation

Node 22. npm ci; npm test. Execute no diretório deste pacote.

PostgreSQL embarcado PGlite com schema descartável em memória. Tabelas pré-requisito sintéticas, helpers de autorização lidos diretamente das migrations 0016/0018 e aplicação integral da 0043. Nenhum segredo, seed legado ou acesso remoto.

O teste cobre fluxo M0–M4, autorização, RLS e policies SQL do Storage. Não equivale a validar Supabase Auth/Storage HTTP, esquema completo 0001–0042, Vercel ou Gemini. O pacote é exclusivo de validação; nenhuma dependência é adicionada ao runtime do portal.
