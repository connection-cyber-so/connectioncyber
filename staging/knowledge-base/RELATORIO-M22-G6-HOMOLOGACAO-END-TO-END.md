# M22 — G6 Homologação end-to-end — 0.1.2

Data: 14/09/2026. Ambiente: Supabase `ozvylnaipubrmaadikvk`, branch `staging` e Vercel Preview.

## Resultado

- Migration 0043, bucket privado, RLS e 12 policies confirmados.
- Três contas sintéticas validadas; dois curadores exigem MFA/AAL2 e o assinante permanece AAL1 sem `knowledge.manage`.
- Jornada real M0–M4 concluída com revisão independente; item final em revisão 9 e score 92/100.
- Upload e download Storage HTTP confirmados, com SHA256 verificado.
- Catálogo, busca/filtros, item, versões, auditoria, favoritos, avaliação, download e curadoria confirmados no navegador publicado.
- CI remoto aprovado para portal, platform, site, contratos e verificações de segurança.
- Preview ativo em `connectioncyber-portal-git-staging-connectioncyberso.vercel.app`; produção não alterada.

## IA

O consentimento e a chamada real ao Gemini foram auditados com conteúdo sintético. O modelo descontinuado foi substituído por `gemini-3.8-flash`. Respostas transitórias 429/5xx e timeouts passaram a usar repetição limitada. O provedor respondeu 503 após as tentativas finais; o sistema manteve o fluxo manual disponível e não avançou gates automaticamente.

## Segurança operacional

As credenciais sintéticas foram rotacionadas após a validação e armazenadas somente em arquivo Windows DPAPI na pasta privada de trabalho. Nenhuma chave, senha, token ou TOTP consta nos artefatos. Mercado Pago, Supabase de produção, Vercel Production e dados reais permaneceram intocados.
