# Validação M13 — migration 0030 no Supabase staging

Data: 28/08/2026  
Projeto: `ozvylnaipubrmaadikvk`  
Migration preservada: `0030_m13_fiscal_a1.sql`  
SHA-256 normalizado: `C88D8940AC49AF7F3EC1FA284EE1C7117DEA53E25AA3C8AA7112882141487F49`

## Resultado

- histórico local/remoto alinhado de `0001` a `0030`;
- 100/100 asserções pós-aplicação aprovadas em modo fail-closed;
- 14 tabelas M13 com RLS ativo;
- seis permissões fiscais presentes;
- zero regimes, perfis, regras, schemas, séries ou reservas;
- zero documentos, itens, transmissões, eventos, artefatos ou contingências;
- zero referências de certificado e zero webhooks;
- nenhum PFX, CSC, certificado, XML ou dado fiscal real criado;
- produção não acessada.

## Normalização

Os quatro falsos negativos da primeira suíte eram nomes automáticos de constraints que excediam o limite de identificador do PostgreSQL. A versão preservada usa nomes explícitos e estáveis: `uq_fiscal_series_context`, `uq_fiscal_document_number`, `uq_fiscal_webhook_event` e `uq_certificate_ref_thumbprint`.

Estado final: migration `0030` aplicada e validada no staging, sem dados. Próximos passos de provedor, certificado, homologação fiscal e produção permanecem em portões separados.
