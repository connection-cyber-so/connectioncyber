# M13-G16 — parecer para primeira autorização NF-e em homologação

Data: 29/08/2026

## Decisão técnica

**Viável com condicionantes.** O motor comum está apto para preparar uma primeira NF-e modelo 55 em homologação, mas o envio não pode permanecer totalmente sintético. A autorização fiscal exige compatibilidade entre certificado, emitente, inscrição estadual, UF, credenciamento e regras tributárias.

O próximo ensaio criará registro persistente na SEFAZ de homologação: chave, protocolo, CNPJ do emitente, série, número e conteúdo do documento. Não possui validade fiscal de produção, mas é uma alteração externa auditável e irreversível como histórico.

## Componentes globais já validados

- schema NF-e 4.00 oficial `010e_v1.02` e hashes;
- XMLDSig, certificado A1 e cadeia;
- chave de acesso e dígito verificador;
- totais monetários em centavos;
- envelope, lote e idempotência;
- timeout, consulta, duplicidade e reconciliação;
- SOAP 1.2, TLS/mTLS e roteamento por autorizador;
- `NFeStatusServico4` com `cStat=107` em SP, SVRS e SVAN;
- 190/190 testes automatizados.

## Dados obrigatoriamente individuais por empresa

- CNPJ, IE, razão social, endereço, município e UF;
- regime tributário e CRT;
- credenciamento da empresa na homologação estadual;
- certificado A1 correspondente ao emitente;
- série e número reservados para homologação;
- NCM, CFOP, CST/CSOSN e tributação da operação-piloto;
- destinatário e produto conforme regras de homologação aplicáveis.

## Modelo de ameaças

| Risco | Controle obrigatório |
|---|---|
| Envio acidental para produção | URL allowlist de homologação e `tpAmb=2` verificados imediatamente antes do POST |
| CNPJ/certificado divergentes | comparar identidade do A1 e emitente localmente sem registrar o valor |
| Duplicação após timeout | consultar recibo/chave antes de qualquer reenvio |
| Série ou número contaminando produção | faixa exclusiva de homologação por tenant |
| Tributação incorreta | cenário fiscal mínimo aprovado antes da assinatura |
| Vazamento de A1, senha ou XML | chave não exportável, memória efêmera e logs somente técnicos |
| Acesso cruzado entre clientes | tenant, estabelecimento e referência do A1 vinculados no servidor |
| Rejeição tratada como sucesso | aceitar autorização somente com `cStat=100` e protocolo válido |

## Critérios go/no-go

Go somente se todos forem verdadeiros:

1. empresa-piloto credenciada em homologação e UF/autorizador confirmados;
2. A1 válido corresponde ao emitente;
3. série/número exclusivos de homologação;
4. XML passa schema, assinatura, chave, totais e regras locais;
5. endpoint pertence à allowlist de homologação;
6. payload final é apresentado por hash e resumo, nunca por conteúdo sensível;
7. autorização explícita menciona uma única NF-e e proíbe reenvio automático.

## Escopo recomendado do próximo portão

M13-G17 deve preparar o documento real da empresa-piloto localmente e executar preflight completo **sem transmitir**. Somente um portão posterior poderá autorizar exatamente um envio persistente à SEFAZ de homologação.

## Estado externo

Esta análise não enviou NF-e, não criou protocolo, não usou CSC, não alterou Supabase e não acessou produção.

