# Auditoria técnica M13-G2 — migration 0030

Data: 28/08/2026  
Escopo: revisão local estática e simulada; sem execução remota.

## Bloqueios encontrados e remediações

| ID | Severidade | Bloqueio | Remediação |
|---|---|---|---|
| A01 | Crítica | `UNIQUE NULLS NOT DISTINCT` limitava transmissões/eventos ainda sem ID externo a uma linha por tenant/provedor | índices únicos parciais somente quando o ID externo não é nulo |
| A02 | Crítica | documento podia combinar venda e série de estabelecimentos diferentes dentro do mesmo tenant | chaves e FKs compostas incluem estabelecimento, ambiente, modelo e série |
| A03 | Alta | `schema_version` era texto livre | FK obrigatória para catálogo global por modelo e versão |
| A04 | Alta | contingência não comprovava NFC-e modelo 65 | coluna fixa `document_model=65` e FK composta com o documento |
| A05 | Crítica | `secret_ref` aceitava conteúdo arbitrário que poderia esconder segredo real | formato fechado para referências `vault://`, `hsm://`, `provider://` ou `seal://` |
| A06 | Alta | tipo do evento podia divergir do estado aplicado | mapeamento obrigatório evento↔estado na RPC |
| A07 | Crítica | pacote Node bloqueava produção, mas RPC SQL não tinha kill switch equivalente | `app.fiscal_production_enabled` permanece falso/ausente por padrão na reserva e no webhook |
| A08 | Crítica | operador podia declarar autorização e grants do broker eram incoerentes | operador limitado a validar/enfileirar/cancelar com AAL2; somente broker processa assinatura, transmissão e resposta fiscal |

## Evidências

- migration continua transacional;
- 14 tabelas com RLS e grants explícitos;
- seis permissões fiscais e quatro RPCs `security definer` com `search_path=''`;
- reserva usa lock de linha e idempotência antes/depois do lock;
- criação e transição repetidas retornam o objeto existente;
- rollback remove objetos M13 e a chave composta adicionada em `erp_sales`;
- 50/50 testes Node aprovados;
- 100 asserções pgTAP preparadas com rollback final;
- zero PFX, CSC, certificado, XML, credencial ou dado fiscal real.

## Limite atual

Docker/PostgreSQL local permanece indisponível por permissão do serviço Windows. Portanto, as 100 asserções ainda precisam de execução transacional antes de qualquer aplicação persistente. A indisponibilidade não foi contornada com acesso remoto.

## Conclusão

Os oito bloqueios identificados foram remediados localmente. Não há bloqueio crítico conhecido na revisão estática; a prontidão definitiva depende da execução PostgreSQL transacional das 100 asserções.
