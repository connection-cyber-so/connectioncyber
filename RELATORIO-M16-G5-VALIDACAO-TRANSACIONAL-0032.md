# M16-G5 — validação transacional remota da 0032

Data: 31/08/2026

Projeto autorizado: Supabase staging `ozvylnaipubrmaadikvk`

## Resultado

**Aprovado com rollback integral. A migration não foi aplicada persistentemente.**

## Sequência executada

1. vínculo confirmado com `connectioncyber-staging`;
2. histórico remoto confirmado até `0031`;
3. dry-run selecionou exclusivamente `0032`;
4. primeiro preflight detectou nome incorreto de membership e depois colisão com objetos canônicos da `0016`;
5. migration normalizada para estender catálogo e entitlements existentes;
6. preflight final retornou `M16_G3_PREFLIGHT_OK`;
7. migration e pgTAP executados em uma transação única;
8. 60/60 asserções aprovadas;
9. transação encerrada com `ROLLBACK`;
10. verificação remota confirmou zero resíduos.

## Evidências finais

- SHA-256: `237485033a7484147315adeda8184b837298e55982c9741f86cd9e7418c7e3f3`;
- testes locais: 54/54;
- pgTAP remoto: 60/60;
- histórico `0032`: ausente;
- tabela de exceções: ausente;
- novas colunas e RPCs: ausentes;
- capacidade `device.agent`: ausente;
- permissão `capabilities.read`: ausente;
- fixtures sintéticas: zero;
- dry-run final: somente `0032` pendente.

## Limites preservados

- nenhuma conta ou dado real criado;
- nenhuma aplicação persistente;
- produção não acessada;
- nenhum push de migration executado.

## Marcador

`M16_G5_0032_TRANSACTION_ROLLBACK_OK`

## Próximo portão

M16-G6 — aplicação persistente exclusiva da `0032` no Supabase staging e repetição das 60 asserções. Exige autorização específica.
