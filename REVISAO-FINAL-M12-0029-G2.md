# Revisão final local — M12 / migration 0029

**Data:** 28/08/2026  
**Resultado:** aprovada para portão de validação transacional  
**SHA-256 da migration:** `78b25f9123682db5729653c106bf4e0881873aadbd1d32799c466e8023ef3bd5`  
**Supabase alterado:** não  
**Produção acessada:** não

## Verificações aprovadas

- Migration inicia com `BEGIN` e termina com `COMMIT`.
- 12 tabelas possuem ativação de RLS.
- Sete RPCs usam `SECURITY DEFINER` e `search_path` vazio.
- Ativação, resultado de comando e ingestão assinada são negados a `authenticated` e concedidos somente ao broker `service_role`.
- Contexto composto e cadeia offline possuem constraints explícitas.
- Preflight verifica MFA, dependências, colisão de objetos e as cinco permissões.
- Rollback remove as novas RPCs e recusa execução quando há dados independentes.
- Plano pgTAP declara exatamente 84 asserções.

## Evidências

- Testes estáticos da migration: `8/8`.
- Testes do protocolo: `12/12`.
- Testes dos simuladores: `7/7`.
- Total local: `27/27`.
- `git diff --check`: aprovado.

## Limite do parecer

A revisão prova coerência estática e comportamento do código local. A sintaxe e os objetos PostgreSQL ainda precisam ser comprovados no Supabase staging dentro de uma transação integral com `ROLLBACK`. Isso exige autorização específica e não autoriza aplicação persistente.

## Próximo portão

Executar preflight remoto e validar a migration `0029` em transação com `ROLLBACK`, seguida das 84 asserções. Não registrar a migration no histórico, não criar dados reais e não acessar produção.
