# M18-G19 — aplicação persistente da migration 0034

Data: 01/09/2026

Ambiente: Supabase staging `ozvylnaipubrmaadikvk`

Resultado: **APLICADA E VALIDADA**

## Evidências

- Histórico e dry-run iniciais confirmaram somente a `0034` pendente.
- Preflight: `M18_0034_PREFLIGHT_OK`.
- Migration aplicada: `0034_m18_protected_pilot_provisioning.sql`.
- pgTAP estrutural: 72/72.
- pgTAP adversarial sintético: 18/18, com rollback.
- Verificação final: `M18_G19_0034_APPLIED_90_OF_90_ZERO_DATA`.
- Histórico final: `0034/0034`.
- Dry-run final: banco remoto atualizado, zero migrations pendentes.

## Estado de segurança

- Outbox e compensações com RLS e sem leitura para `anon` ou `authenticated`.
- Quatro RPCs disponíveis exclusivamente para `service_role`.
- Zero tenant Mania de Modas, zero tenant sintético, zero outbox, zero compensação e zero run M18.
- Nenhuma conta Auth, membership ou identidade foi criada.
- Produção não foi acessada.

## Próximo portão

M18-G20 — coleta local protegida e preflight final dos dados reais do tenant e usuário-piloto, sem gravar no Supabase. A criação efetiva e o convite Auth continuarão em autorização separada.
