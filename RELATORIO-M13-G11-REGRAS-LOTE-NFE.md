# M13-G11 — regras de negócio, envelope e lote NF-e

Data: 28/08/2026

## Resultado

- Composição determinística da chave de acesso NF-e com 43 dígitos-base e módulo 11.
- Validação da chave final de 44 dígitos e rejeição determinística de DV divergente.
- Identidade fiscal aceita somente como marcador sintético zerado neste portão.
- Reconciliação monetária executada em centavos inteiros.
- Itens, descontos, frete, seguro, outros valores, IPI, ST, desoneração, pagamentos e total conferidos.
- Envelope `enviNFe` versão 4.00 criado apenas em memória.
- `idLote` de até 15 dígitos derivado de chave e idempotência.
- Reenvio do mesmo conteúdo retorna duplicidade sem criar novo lote.
- Colisão do mesmo lote com conteúdo diferente gera rejeição local.
- 148/148 testes locais aprovados.

## Evidência automática

`M13_G11_LOCAL_RULES_OK`: chave válida, totais válidos, lote idempotente e envelope construído.

## Controles preservados

- identidade: sintética;
- certificado A1 utilizado: `false`;
- assinatura: `false`;
- XML persistido: `false`;
- CSC utilizado: `false`;
- transmissão: `false`;
- produção acessada: `false`;
- Supabase remoto alterado: `false`.

## Próximo portão

M13-G12 — máquina de estados de autorização NF-e e simulador local de respostas SEFAZ: lote recebido, processamento, autorização, rejeição, duplicidade, timeout, consulta e reconciliação, sem rede.

