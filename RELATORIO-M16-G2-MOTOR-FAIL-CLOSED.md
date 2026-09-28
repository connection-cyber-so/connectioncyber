# M16-G2 — motor de resolução fail-closed

Data: 30/08/2026

## Entrega

- dependências canônicas entre capacidades;
- estados `enabled`, `disabled` e `blocked`;
- prontidão obrigatória para fiscal, suporte remoto, agente local e importação;
- propagação de bloqueios para módulos dependentes;
- matriz sintética MEI, ME e LTDA;
- capacidade ou sinal desconhecido bloqueado por padrão.

## Regras principais

- contrato negado resulta em `disabled`;
- dependência indisponível resulta em `blocked`;
- prontidão ausente nunca é presumida;
- perfil jurídico não substitui validação fiscal ou operacional;
- nenhuma resolução local concede acesso remoto ou produção.

## Validação

- Node.js 22.23.2;
- 37/37 testes aprovados;
- MEI: estoque permanece desabilitado no blueprint atual;
- ME: estoque e serviços habilitados pelo contrato atual;
- LTDA: fiscal, suporte remoto, agente e importação bloqueados sem prontidão explícita;
- negações em catálogo, vendas ou caixa propagam bloqueio aos dependentes;
- simulador executado sem banco, rede ou persistência.

## Próximo gate

M16-G3 — preparar localmente a migration `0032` para persistir catálogo, entitlements e exceções tenant-scoped, com RLS, preflight, rollback e pgTAP. Aplicação remota continuará bloqueada.

## Marcador

`M16_G2_FAIL_CLOSED_ENGINE_OK`
