# M18-G1 — cliente server-side tipado

Data: 31/08/2026

Resultado: aprovado localmente com dublês.

## Entrega

- Cliente server-side para os sete comandos `erp_command_*_v1`.
- Declarações TypeScript para comandos, read models, payload JSON, transporte e resultados.
- Transporte injetável para testes sem rede.
- Tenant resolvido exclusivamente por função server-side; nunca incorporado ao payload do navegador.
- Request ID validado e SHA-256 canônico calculado no servidor.
- Releitura sequencial dos read models contratados antes de retornar sucesso.
- Erros convertidos para superfície pública estável, sem detalhe SQL e sem retry automático de escrita.

## Fluxo fixado

```text
payload do formulário
  -> triagem de autoridade/segredo/tamanho
  -> resolver tenant no servidor
  -> calcular request-id e hash
  -> executar uma RPC versionada
  -> reler modelos afetados
  -> devolver sucesso somente após releitura
```

## Evidências

- 48/48 testes do pacote aprovados.
- Sete comandos chamaram sete RPCs distintas nos dublês.
- Venda executou uma RPC seguida de quatro releituras.
- Falha na RPC não iniciou releitura.
- Falha na releitura impediu estado de sucesso.
- Declarações TypeScript compiladas em modo estrito.
- Simulador: `M18_G1_TYPED_SERVER_CLIENT_OK`.
- 32/32 testes da plataforma, TypeScript e ESLint aprovados.
- Varredura de identificadores e credenciais reais: limpa.
- Supabase, banco, Vercel, GitHub remoto e produção não acessados.

## Limite atual

O cliente ainda não foi ligado a formulários ou páginas reais. O M18-G2 fará a primeira integração visual local de cadastro e catálogo, mantendo transporte remoto bloqueado.

Marcador: `M18_G1_TYPED_SERVER_CLIENT_OK`.

Próxima etapa automática: **M18-G2 — integrar cadastro de cliente e produto à fronteira server-side, inicialmente com transporte local e testes sintéticos.**
