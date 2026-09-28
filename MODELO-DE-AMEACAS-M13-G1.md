# Modelo de ameaças M13-G1 — fiscal

| ID | Ameaça | Controle obrigatório | Teste/monitoramento |
|---|---|---|---|
| F01 | vazamento de PFX/senha/CSC/token | cofre externo, referência opaca, bloqueio de campos | varredura recursiva e secret scanning |
| F02 | emissão cross-tenant | RLS, tenant derivado no servidor, credencial por empresa | testes positivos e negativos |
| F03 | mistura homologação/produção | filas, URLs, credenciais, séries e storage separados; kill switch | produção recusada por padrão |
| F04 | número duplicado por concorrência | lock/reserva transacional e unicidade | corrida concorrente |
| F05 | reemissão após timeout | estado `unknown`, consulta e reconciliação | simulador de resposta perdida |
| F06 | webhook forjado/repetido | assinatura/mTLS quando disponível, inbox, hash e deduplicação | assinatura inválida e replay |
| F07 | XML/protocolo adulterado | storage imutável criptografado e SHA-256 | alteração muda hash |
| F08 | transição ilegal de estado | máquina de estados no domínio e banco | matriz de transições |
| F09 | regra tributária vencida | catálogo versionado por vigência, UF e hash | teste de fronteira temporal |
| F10 | contingência indevida | somente NFC-e, permissão por UF/vigência | NF-e offline recusada |
| F11 | provedor indisponível/lock-in | contrato neutro, fila durável, exportação e consulta | adaptador simulado e exportação |
| F12 | operador privilegiado abusivo | AAL2, segregação de função e auditoria append-only | autorização negativa e alerta |
| F13 | log com dado/segredo fiscal | allowlist de campos, mascaramento e retenção | teste de conteúdo proibido |
| F14 | certificado vencido/revogado | alerta antecipado, bloqueio e rotação auditada | relógio sintético |
| F15 | resposta válida associada ao documento errado | conferir tenant, ambiente, modelo, chave/ref e hash | evento divergente recusado |

Fora deste portão: upload de certificado, assinatura XML, comunicação SEFAZ, contratação e emissão em homologação/produção.
