# Matriz técnica preliminar de provedores M13-G1

Data da verificação: 28/08/2026. Esta matriz não é uma contratação nem certifica SLA, preço, segurança interna ou aderência fiscal. Esses pontos exigem proposta, DPA/LGPD, evidências de segurança e prova de conceito.

| Critério verificável | Focus NFe | PlugNotas/TecnoSpeed | Integração direta SEFAZ |
|---|---|---|---|
| NF-e e NFC-e | documentado | documentado | possível por UF/webservices |
| Homologação separada | URL documentada | configuração `producao:false` documentada | endpoints/certificação oficiais |
| Processamento assíncrono | fila, consulta e webhook | ID, consulta e webhook | implementação própria |
| Multiempresa/SaaS | API de empresas documentada | callbacks por software house/empresa | isolamento totalmente próprio |
| Custódia A1 | upload/custódia pelo fornecedor documentados | rota/cadastro A1 documentados | cofre, assinatura e rotação próprios |
| XML/DANFE | consulta e backup documentados | geração/retorno documentados | geração, guarda e renderização próprias |
| Contingência NFC-e | recursos existem; validar cobertura por UF em PoC | validar cobertura por UF em PoC | implementar e manter por UF |
| Autenticidade de webhook | **diligência obrigatória**: confirmar assinatura, não apenas retries | **diligência obrigatória**: confirmar assinatura/segredo | não aplicável; autenticação SEFAZ própria |
| Esforço operacional | menor | menor | máximo |
| Lock-in | mitigado por adaptador e exportação | mitigado por adaptador e exportação | baixo no fornecedor, alto na manutenção fiscal |
| Preço, SLA e suporte | proposta pendente | proposta pendente | custo interno a estimar |

## Parecer

Shortlist para prova de conceito: Focus NFe e PlugNotas, sem escolha antecipada. A PoC deve usar o mesmo conjunto sintético, medir latência/recuperação, repetição, consulta após timeout, exportação XML, segregação por empresa e comportamento de webhook. Integração direta fica como alternativa futura, não como primeira implementação.

## Critério eliminatório

Fornecedor é eliminado se não comprovar: segregação multiempresa, exportação integral, ambiente de homologação, idempotência/reconciliação, processo seguro de A1, notificação autenticável, resposta a incidente, LGPD/DPA e saída contratual.

## Fontes dos fornecedores

- Focus NFe — introdução/API: https://doc.focusnfe.com.br/reference/introducao
- Focus NFe — ambientes: https://doc.focusnfe.com.br/reference/ambiente
- Focus NFe — webhooks/retries: https://doc.focusnfe.com.br/reference/webhooks
- PlugNotas — NF-e/NFC-e: https://atendimento.tecnospeed.com.br/hc/pt-br/articles/38024197110295
- PlugNotas — callbacks: https://atendimento.tecnospeed.com.br/hc/pt-br/articles/360033197014
