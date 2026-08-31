# Persistent journey contract

Contrato local M17-G1 para a jornada persistente multiempresa. Define comandos, estados, idempotência, erros públicos seguros e um simulador transacional exclusivamente em memória.

Regras centrais:

- `tenantId`, ator, papéis e capacidades vêm somente do contexto resolvido no servidor;
- comandos do navegador não podem conter campos de autoridade;
- replay idêntico retorna o resultado anterior;
- mesma chave com payload diferente falha fechado;
- qualquer falha no fluxo integrado restaura o snapshot inteiro;
- payloads reais, segredos, rede e persistência são proibidos nesta etapa.

```powershell
Set-Location -LiteralPath "F:\Projetos\connectioncyber-staging\packages\persistent-journey-contract"
$env:PATH = "$env:TEMP\connectioncyber-node22\node-v22.23.2-win-x64;$env:PATH"
npm test
npm run simulate
npm run simulate:authorization
```
