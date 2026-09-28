# Modelo de ameaças M12-G1 — agente local e periféricos

**Escopo:** contrato entre agente, broker e operações offline.  
**Fora do escopo:** driver real, TEF homologado, certificado A1, produção e acesso remoto de tela.

| Ameaça | Controle G1 | Evidência |
|---|---|---|
| Agente de outro tenant executa comando | tenant, estabelecimento e agente assinados; verificação por contexto esperado | teste de tenant/agente divergente |
| Replay de impressão, gaveta ou TEF | nonce único, TTL e idempotência | teste de replay |
| Comando adulterado | Ed25519 sobre JSON canônico | teste de alteração pós-assinatura |
| Relógio manipulado | TTL de 5 minutos, tolerância futura de 30 segundos e relógio do broker como autoridade | testes de expiração/TTL |
| Roubo do banco local | pacote mínimo, expiração, criptografia futura por DPAPI/SQLite e ausência de segredo global | contrato proíbe segredo |
| Vazamento em payload/log | rejeição recursiva de chaves sensíveis | teste de segredo aninhado |
| Alteração da fila offline | hash encadeado e IDs únicos | testes de cadeia e adulteração |
| Downgrade de protocolo | versão obrigatória e recusa de desconhecida | teste de versão |
| Agente revogado continua operando | broker verifica estado/chave antes de entregar e aceitar resultado | será teste de integração G3 |
| Atualização maliciosa | manifesto e binário assinados, canal TLS e rollback | será prova do instalador G5 |
| TEF duplica cobrança após timeout | chave idempotente e estado `manual_review` | será simulador G3 |
| Impressão duplicada altera venda | impressão é efeito auditável separado da transação comercial | será simulador G3 |

## Fronteiras de confiança

1. Navegador não é autoridade sobre tenant, agente, preço, pagamento ou peso.
2. Agente local é componente potencialmente comprometível; o servidor revalida identidade, escopo e estado.
3. Periférico fornece observação, não autorização comercial.
4. Broker é a única fronteira que entrega comandos e aceita resultados.
5. Supabase guarda estado e auditoria; não entrega `service_role` ao agente.

## Riscos residuais antes do piloto

- proteção física e malware no terminal;
- compatibilidade dos drivers e protocolos dos equipamentos reais;
- armazenamento seguro da chave privada no Windows;
- assinatura e distribuição do instalador;
- comportamento específico do provedor TEF em timeout e reversão;
- operação fiscal offline, tratada exclusivamente no M13.

Nenhum desses riscos autoriza reduzir MFA, RLS, assinatura, idempotência ou auditoria.
