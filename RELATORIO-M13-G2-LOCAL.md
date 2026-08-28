# Relatório M13-G2 — migration local 0030

Data: 28/08/2026  
Escopo: somente arquivos locais em `connectioncyber-staging`.

## Entregas

- migration `0030_m13_fiscal_a1.sql` com 14 tabelas, RLS, seis permissões e quatro RPCs;
- preflight determinístico `M13_0030_PREFLIGHT_OK`;
- rollback que remove funções antes das tabelas e limpa permissões M13;
- suíte pgTAP declarada com 89 asserções e `ROLLBACK` final;
- simulador fiscal sem rede, XML, certificado, CSC, provedor ou dado real;
- 41/41 testes Node aprovados e schemas JSON válidos.

## Resultado honesto do laboratório

O runtime Docker Desktop estava parado. A tentativa de iniciar o serviço local foi recusada pelo Windows (`Cannot open com.docker.service`), e `supabase start` confirmou ausência do engine. Por isso, a migration e as 89 asserções pgTAP não foram executadas em PostgreSQL neste portão. Nenhum comando remoto foi usado como alternativa.

## Estado de segurança

- Supabase staging remoto: não acessado;
- produção: não acessada;
- migration 0030: não aplicada em banco algum;
- certificados, PFX, senhas, CSC, tokens, XML, documentos e dados reais: zero;
- próximo passo: auditoria técnica local estática da 0030 e, depois, laboratório transacional com runtime PostgreSQL disponível.
