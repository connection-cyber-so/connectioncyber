# M18-G10 — normalização dos read models persistentes

Data: 01/09/2026

Estado: aprovado localmente

Marcador: `M18_G10_PERSISTENT_READ_MODELS_NORMALIZED_LOCAL_OK`

## Escopo concluído

- Normalização fail-closed dos read models persistentes para os formatos consumidos pelas telas.
- Isolamento por `tenant_id` verificado em todas as linhas antes da transformação.
- Clientes e produtos limitados a registros ativos; vendas limitadas a concluídas; financeiro limitado a recebíveis.
- Estoque, caixa, vendas, parcelas e financeiro convertidos para nomes e tipos visuais canônicos.
- Dashboard persistente alinhado ao dashboard local, incluindo reconciliação entre vendas, dinheiro, crediário e liquidações confirmadas.

## Controles

- Número inválido, read model desconhecido, liquidação excessiva e linha cross-tenant falham fechado.
- Nenhum cliente Supabase foi ativado nas telas.
- Nenhum serviço remoto, migration ou dado real foi acessado ou alterado.

## Evidências

- Node.js: `22.23.2`.
- Adaptador persistente: `44/44` testes.
- Contrato visual persistente: `50/50` testes.
- Plataforma: `80/80` testes.
- TypeScript, ESLint e build Next.js: aprovados.

## Parecer

Os formatos persistentes estão compatíveis com a fronteira visual local e prontos para o próximo gate local. A ativação remota das telas permanece bloqueada.
