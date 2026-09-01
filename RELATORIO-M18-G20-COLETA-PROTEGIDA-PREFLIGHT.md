# M18-G20 — coleta protegida e preflight final

Data: 01/09/2026

## Resultado

- Mecanismo local de coleta protegida implementado e aprovado.
- Quatro campos obrigatórios são validados em memória: razão social, CNPJ, inscrição estadual e e-mail do owner.
- Entrada mascarada; cofre cifrado por DPAPI fora do projeto e do Git.
- Preflight remoto somente leitura aprovado: `M18_G20_REMOTE_PREFLIGHT_OK`.
- Testes focados: 8/8; testes da plataforma, TypeScript, ESLint e build aprovados com Node.js 22.
- Nenhuma gravação foi realizada no Supabase; produção não foi acessada.

## Estado do portão

`M18-G20 APROVADO COM COLETA LOCAL PENDENTE`.

O cofre protegido ainda não existe. A única intervenção necessária é informar localmente os quatro valores na janela mascarada. Valores fiscais e identidade não devem ser enviados ao chat, terminal, Git, banco, relatório ou logs.

Após a coleta, o validador deve retornar `M18_G20_PROTECTED_CONFIG_OK`. A criação efetiva de tenant e usuário permanece bloqueada em portão separado.

## Remediação do coletor

- A primeira execução foi bloqueada porque o Windows PowerShell não carregou automaticamente `Microsoft.PowerShell.Security`.
- Nenhum valor foi gravado nessa tentativa.
- A dependência dos cmdlets do módulo foi removida; a proteção agora usa DPAPI `CurrentUser` diretamente.
- Parser PowerShell, ASCII, ida e volta DPAPI sintética e 8/8 testes foram aprovados: `M18_G20_DPAPI_REMEDIATION_OK`.
