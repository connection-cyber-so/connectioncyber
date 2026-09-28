# Capability contract

Contrato local e sintético para resolver capacidades por tenant. Os perfis MEI, ME e LTDA são blueprints iniciais, não autorização jurídica nem regra fiscal. Exceções exigem identificador, justificativa, aprovador e expiração; capacidade desconhecida permanece bloqueada.

```powershell
Set-Location -LiteralPath "F:\Projetos\connectioncyber-staging\packages\capability-contract"
$env:PATH = "$env:TEMP\connectioncyber-node22\node-v22.23.2-win-x64;$env:PATH"
npm test
npm run simulate
```
