# Parecer de prontidão M13-G2 — migration 0030

Data: 28/08/2026  
Migration: `0030_m13_fiscal_a1.sql`  
SHA-256: `09C88A5594A1D46F413646416018DBC0A95311A0899669D211C449169B6CC750`

## Parecer

A migration `0030` está **apta para preflight remoto somente leitura e validação transacional com ROLLBACK no Supabase staging**, condicionada à autorização explícita. Ela ainda não está autorizada para aplicação persistente.

## Evidências finais

- escopo local sequencial: `0029` aplicada anteriormente; `0030` é a única migration nova;
- 14 tabelas fiscais, RLS, seis permissões e quatro RPCs;
- separação de autoridade: operador valida/enfileira; broker assina/transmite/importa resultado; cancelamento exige `fiscal.cancel` e AAL2;
- produção bloqueada por padrão no pacote e no SQL;
- oito bloqueios da auditoria remediados;
- 50/50 testes Node aprovados;
- 100 asserções pgTAP preparadas com `ROLLBACK` final;
- preflight esperado: `M13_0030_PREFLIGHT_OK`;
- zero certificado, PFX, CSC, XML, documento, webhook ou dado fiscal real.

## Procedimento autorizado no próximo portão

1. executar somente o preflight da `0030` no projeto staging `ozvylnaipubrmaadikvk`;
2. confirmar o SHA-256 acima e que a `0030` ainda não consta do histórico remoto;
3. executar migration e pgTAP dentro da mesma transação descartável;
4. confirmar `100/100`, rollback e ausência de todos os objetos M13;
5. não registrar histórico, não persistir schema e não acessar produção.

## Frase de autorização

`Autorizo executar o preflight remoto e validar exclusivamente a migration 0030 no Supabase staging ozvylnaipubrmaadikvk dentro de transação com ROLLBACK, executando as 100 asserções; não aplicar persistentemente a 0030, não criar certificados, documentos fiscais, XMLs, transmissões, webhooks ou dados reais e não acessar produção.`
