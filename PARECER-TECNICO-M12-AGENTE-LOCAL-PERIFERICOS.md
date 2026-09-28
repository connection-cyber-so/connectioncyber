# Parecer técnico M12 — agente local, periféricos e contingência

**Data:** 28/08/2026  
**Ambiente:** staging  
**Estado:** parecer técnico concluído; implementação não iniciada  
**Supabase alterado:** não  
**Produção acessada:** não

## 1. Decisão executiva

O M12 é viável, mas não deve colocar impressoras, portas seriais, TEF ou armazenamento offline diretamente no navegador. A solução recomendada é um **agente Windows local, assinado e com privilégios mínimos**, separado do Next.js e conectado ao backend somente por canal TLS de saída.

O agente não receberá `service_role`, senha do banco, chave privada fiscal ou credencial global. Cada instalação terá identidade própria, revogável e vinculada a um único tenant e estabelecimento.

## 2. Arquitetura aprovada

```text
Portal/PDV Next.js
        |
        | HTTPS autenticado
        v
API/Edge broker + Supabase staging
        |
        | fila de comandos, eventos e confirmações
        | TLS de saída iniciado pelo agente
        v
Agente Windows por estabelecimento
   |           |           |           |
Spooler     Serial/USB   Adaptador    SQLite local
impressão   balança      TEF          criptografado
```

### Componentes

- `apps/agent-api`: contratos HTTP/Edge, autenticação do dispositivo e entrega de comandos; não será criado antes do contrato G1.
- `apps/windows-agent`: serviço Windows responsável por periféricos e contingência; tecnologia final será decidida por prova de conceito entre .NET e Node empacotado.
- `packages/device-protocol`: mensagens versionadas, schemas, estados, códigos de erro e idempotência.
- Supabase: cadastro do agente, chaves públicas, comandos, tentativas, confirmações e trilha de auditoria.
- SQLite local criptografado: fila de saída e snapshot mínimo necessário à contingência, nunca cópia integral do ERP.

## 3. Segurança obrigatória

1. Pareamento iniciado por usuário autenticado com MFA e código de uso único, curto e expirável.
2. Chave privada gerada no próprio computador e protegida por DPAPI ou armazenamento criptográfico do Windows.
3. Autenticação por chave de dispositivo e token efêmero; nenhuma chave global no agente.
4. Comunicação exclusivamente de saída por TLS; nenhuma porta pública ou túnel permanente.
5. Comandos assinados, com tenant, estabelecimento, agente, nonce, expiração e chave de idempotência.
6. Atualizações do agente assinadas, verificadas e com rollback de versão.
7. Logs sem PAN, senha, token bruto, certificado A1, conteúdo de área de transferência ou documento integral desnecessário.
8. Revogação imediata do agente e rotação de chave sem reinstalar toda a plataforma.

## 4. Periféricos

### Impressão e etiquetas

- Adaptadores separados para spooler Windows, ESC/POS, ZPL e PDF.
- Template renderizado de forma determinística e versionado no servidor.
- Reimpressão gera novo evento de auditoria, mas não duplica venda, pedido ou item de cozinha.
- Comando registra hash do documento, impressora lógica, cópias e resultado; conteúdo sensível tem retenção mínima.

### Balanças

- Adaptadores por protocolo serial/USB e modelo homologado.
- Leitura exige estabilidade, unidade, precisão e timestamp.
- Peso recebido do agente nunca é autoridade isolada: servidor valida faixa, produto fracionável e contexto da operação.

### Gaveta e displays

- Abertura da gaveta exige permissão, caixa aberto e motivo auditável quando fora de uma venda.
- Display do cliente recebe somente dados estritamente necessários à transação atual.

### TEF

- TEF será um adaptador para provedor homologado, não implementação própria de processamento de cartão.
- A plataforma não armazenará PAN completo, CVV, trilha magnética ou PIN.
- Serão persistidos somente identificadores autorizados: NSU, autorização, bandeira, parcelas, valor, status e referência mascarada permitida.
- Venda e pagamento usarão máquina de estados idempotente; timeout não será interpretado automaticamente como falha definitiva.
- Homologação com provedor e adquirente será um portão externo específico.

## 5. Contingência offline

Offline não significa replicar livremente o banco. O agente manterá apenas um pacote assinado e expirável com:

- produtos ativos e preços aplicáveis ao estabelecimento;
- formas de pagamento permitidas offline;
- sequência reservada e regras operacionais não fiscais;
- permissões mínimas da sessão já autenticada;
- fila append-only de operações pendentes.

Cada operação offline terá `operation_id`, tenant, estabelecimento, terminal, sequência, horário local, versão do snapshot e hash encadeado. A sincronização será idempotente e retornará estados `accepted`, `rejected` ou `manual_review`.

Conflitos financeiros, estoque negativo, preço vencido ou sequência divergente nunca serão corrigidos silenciosamente. Eles irão para reconciliação. Emissão fiscal offline pertence ao M13 e não será simulada no M12.

## 6. Modelo de dados previsto

A futura migration `0029` deverá ser aditiva e conter, no mínimo:

- agentes e instalações por tenant/estabelecimento;
- chaves públicas, pareamentos e revogações;
- periféricos descobertos e configurações lógicas;
- comandos, tentativas, confirmações e eventos;
- pacotes offline, reservas de sequência e operações pendentes;
- reconciliações e conflitos;
- versões do agente e políticas de atualização.

Todas as tabelas terão `tenant_id`, RLS, constraints compostas cross-tenant, idempotência e retenção definida. A migration não criará dispositivos ou dados reais.

## 7. Limites do M12

- Não inclui certificado A1, NF-e, NFC-e ou regras fiscais; pertencem ao M13.
- Não cria protocolo proprietário de captura de tela ou controle remoto; o M11 mantém consentimento e auditoria.
- Não instala serviço Windows em computador real nesta fase.
- Não contrata nem ativa provedor TEF.
- Não promove código ou schema para produção.

## 8. Fases determinísticas

| Portão | Entrega | Critério de saída |
|---|---|---|
| M12-G0 | Parecer e limites | Arquitetura, ameaças e exclusões documentadas. |
| M12-G1 | Contrato do protocolo | Schemas versionados, estados, assinatura, idempotência e erros testados. |
| M12-G2 | Migration local 0029 | Preflight, rollback e testes de RLS/segurança aprovados localmente. |
| M12-G3 | Simulador do agente | Impressora, balança, TEF e offline simulados sem hardware ou credenciais. |
| M12-G4 | Validação no staging | Migration autorizada, testes remotos e zero dados reais. |
| M12-G5 | Piloto físico | Equipamentos inventariados, agente assinado e testes presenciais aprovados. |

## 9. Critérios mínimos de aceite

- Um agente de um tenant não lê nem executa comandos de outro.
- Replay, comando expirado, assinatura inválida e agente revogado são recusados.
- Reenvio do mesmo comando ou operação offline não duplica efeito.
- Falha após pagamento ou impressão é reconciliável e auditável.
- Nenhum segredo global aparece em arquivo, log, instalador ou navegador.
- Desinstalação/revogação impede novas conexões sem apagar a auditoria.
- Simuladores e testes negativos passam antes de qualquer hardware real.

## 10. Próxima etapa automática

Produzir o contrato M12-G1 do protocolo e o modelo de ameaças. Somente depois será seguro implementar a migration local `0029` e o simulador, mantendo qualquer aplicação remota bloqueada.
