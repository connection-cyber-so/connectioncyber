# M22-G5 — Homologação de banco e autorização no Supabase staging

Data: 14/09/2026. Ambiente: `connectioncyber-staging`. Project ref: `ozvylnaipubrmaadikvk`.

## Resultado

Gate aprovado para banco e fronteira de autorização. A migration `0043_m22_knowledge_base.sql` foi aplicada exclusivamente no staging. O histórico remoto ficou alinhado de 0001 a 0043. Produção não foi acessada nem alterada.

## Segurança da execução

- Preflight confirmou os helpers ERP exigidos, ausência de colisão das tabelas e ausência de policies prévias em `storage.objects`.
- Dry-run selecionou somente a 0043; seeds, roles globais e Vault não foram sincronizados.
- Dump local do esquema anterior: 856.267 bytes; SHA-256 `CE1BF2A094B76DF51F5BC6BF4356C4F4E4BF1A975CDC31702974B9F9A51F2EA8`.
- O Supabase não listava backup gerenciado nem PITR para este projeto; o dump cobre o esquema, não os dados do Auth.

## Fixtures sintéticas

Tenant: `kb-homologacao-m22` (`b098c3d0-463f-4d5e-95a4-2f51eb5faa4f`). Validade: até 21/09/2026.

- `curador-1`: membership ativa, entitlement ativo, papel `kb-curator`, permissão `knowledge.manage`, TOTP verificado.
- `curador-2`: membership ativa, entitlement ativo, papel `kb-curator`, permissão `knowledge.manage`, TOTP verificado.
- `assinante`: membership ativa, entitlement ativo, papel `kb-subscriber`, sem `knowledge.manage`.

As contas usam e-mails sintéticos, não enviaram convite e não representam clientes. As credenciais foram armazenadas somente em arquivo local criptografado por Windows DPAPI; nenhum segredo foi gravado na documentação ou no repositório.

## Evidência remota

- Migration 0043 presente no histórico: 1.
- Tenant sintético: 1.
- Profiles sintéticos: 3.
- Memberships ativas: 3.
- Entitlements ativos: 3.
- Grants de curador: 2.
- Bucket `knowledge-base` privado: sim.
- Policies RLS/Storage do módulo: 12.
- Curadores em AAL1: `access=false`, `manage=false`.
- Curadores após TOTP/AAL2: `access=true`, `manage=true`.
- Assinante em AAL1: `access=true`, `manage=false`.

## Limite e próximo gate

Este gate não ativou a feature flag nem executou deploy. Navegador, fluxo M0–M4, upload/Storage HTTP, URL assinada e Gemini permanecem para homologação no Preview da branch staging. Mercado Pago, dados reais e produção permaneceram intactos.
