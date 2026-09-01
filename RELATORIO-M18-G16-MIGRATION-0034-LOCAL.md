# M18-G16 — migration local 0034

Data: 01/09/2026

Resultado: **IMPLEMENTAÇÃO LOCAL CONCLUÍDA; VALIDAÇÃO POSTGRESQL PENDENTE**

## Entregas

- Migration `0034_m18_protected_pilot_provisioning.sql` transacional.
- Inscrição estadual com formato e unicidade tenant-scoped; domínio com unicidade case-insensitive.
- Outbox Auth e ledger de compensação server-only, ambos com RLS e sem policy de cliente.
- Quatro RPCs `service_role`: preparar, registrar identidade Auth, finalizar membership e agendar compensação.
- Preparação atômica de tenant, estabelecimento, owner/MFA, permissões, capacidades, ledger e outbox.
- Preflight read-only, rollback vazio com confirmação e suíte pgTAP de 72 asserções.

## Evidências

- SHA-256 da migration: `DDCF72B5B39D8BD407ECB7B928F547DFDF097F254329BAA0711CC1FC4279C715`.
- Testes estáticos M18-G16: 15/15.
- Plataforma: 142/142; contrato: 50/50; adaptador: 44/44.
- TypeScript, ESLint e build Next.js aprovados em Node.js 22.23.2.
- Supabase remoto e produção não acessados; migration não aplicada.

## Limitação comprovada

O Docker Desktop foi iniciado, mas o engine Linux não respondeu. Por isso, a migration não foi compilada em PostgreSQL local e as 72 asserções pgTAP foram preparadas, porém não executadas. Nenhuma validação remota foi usada como atalho.

## Próximo gate

M18-G17 — auditoria SQL local independente da `0034`, remediação e execução transacional das 72 asserções quando o runtime PostgreSQL local estiver disponível. Aplicação remota continuará bloqueada.
