# Relatório M13-G5 — Focus NFe homologação

Data: 28/08/2026  
Estado: preparação concluída; chamada real bloqueada por ausência do token de homologação.

## Entregas

- adaptador fixado em `https://homologacao.focusnfe.com.br`;
- autenticação Basic preparada somente em memória;
- URL absoluta e produção recusadas;
- payload canônico exclusivamente sintético;
- PFX, certificado, senha, CSC e chaves privadas recusados recursivamente;
- timeout fail-closed, hash de resposta e injeção de `fetch` para testes;
- probe não emissor: apenas valida configuração e contrato, com `networkCall:false`;
- variável documentada: `FOCUS_NFE_HOMOLOGATION_TOKEN`.

## Validação

- 58/58 testes locais aprovados;
- probe sem token retornou `FOCUS_HOMOLOGATION_BLOCKED`;
- nenhuma chamada à Focus NFe foi realizada;
- nenhum certificado, empresa, documento, XML ou dado fiscal foi criado;
- staging Supabase e produção não foram alterados neste portão.

## Bloqueio legítimo

Para continuar a prova técnica, o token de homologação deve existir somente em `apps/platform/.env.local`, arquivo ignorado pelo Git. O valor não deve ser enviado por chat, documentação, commit ou log.
