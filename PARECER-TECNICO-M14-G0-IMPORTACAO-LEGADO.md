# M14-G0 — parecer técnico de importação do legado

Data: 29/08/2026
Decisão: **APROVADO PARA CONTRATOS E SIMULADORES; DADOS REAIS EM PORTÃO SEPARADO**

## Objetivo

Criar um pipeline único de importação por cliente, sem fork de código e com isolamento por tenant.

## Fluxo determinístico

1. preservar a fonte original e calcular SHA-256;
2. inventariar versão, schema, tabelas, volumes e qualidade;
3. extrair para representação canônica temporária;
4. validar, transformar e atribuir tenant exclusivamente no servidor;
5. carregar de forma idempotente, reconciliar e produzir relatório sem dados pessoais.

## Invariantes

- a fonte original nunca é alterada;
- nenhum registro entra sem tenant resolvido no servidor;
- reexecução não duplica entidades ou movimentos;
- totais por domínio precisam reconciliar antes do aceite;
- falha parcial não promove lote incompleto;
- dados reais, backup e credenciais exigem autorização e custódia separadas.

## Próxima etapa

M14-G1: contrato canônico de lote, manifesto de origem, mapeamentos, simulador sintético, rejeições e testes de idempotência. Nenhum backup real será aberto.
