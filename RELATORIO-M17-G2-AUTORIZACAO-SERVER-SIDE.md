# M17-G2 — autorização server-side com dublês locais

Data: 31/08/2026

## Entrega

- Fronteira server-side implementada no pacote da jornada persistente.
- Política explícita relaciona os sete comandos a uma permissão e uma capacidade canônica.
- Sequência de autorização: host normalizado, sessão, tenant ativo, membership, MFA, permissão, capacidade e validação do comando.
- Resultado autorizado contém tenant, ator, membership, papel, capacidade, permissão, chave idempotente e fingerprint do contexto.
- Nenhuma autoridade é aceita do payload enviado pelo navegador.

## Controles fail-closed

- host inválido, desconhecido ou tenant suspenso são recusados;
- sessão ou membership ausente são recusadas;
- divergência entre host, tenant e membership é recusada;
- owner e admin exigem AAL2;
- permissão ausente, capacidade disabled ou desconhecida bloqueiam o comando;
- falha inesperada de dependência vira erro público seguro, sem detalhe interno;
- autorizações e negações geram evidência mínima sem payload nem host.

## Dublês e testes

- Dublês locais representam identidade, tenants, memberships, capacidades e auditoria.
- Todos os identificadores são sintéticos.
- 44/44 testes do pacote aprovados com Node.js 22.23.2.
- Simulação retornou `M17_G2_SERVER_AUTHORIZATION_OK`.
- Regressão da plataforma: 32/32 testes, TypeScript, ESLint e build aprovados.
- Rede, persistência, Supabase e produção não acessados.

## Limite desta etapa

O contrato server-side e seus ports estão prontos. Adaptadores reais para Supabase não foram conectados; isso ocorrerá gradualmente nos próximos gates e exigirá testes de integração separados.

Marcador: `M17_G2_SERVER_AUTHORIZATION_OK`

Próxima etapa automática: M17-G3 — integrar cadastro e catálogo à nova fronteira server-side, inicialmente com repositórios locais e testes sintéticos.
