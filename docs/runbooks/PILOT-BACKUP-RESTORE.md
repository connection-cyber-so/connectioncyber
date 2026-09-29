# Runbook — backup e restauração do piloto

Estado: rotina real disponível (03/09/2026) — `scripts/backup-connectioncyber-staging.ps1`,
adaptada do padrão VaultMindOS/CDP usado em outros projetos do ecossistema. Cobre código
(robocopy pra OneDrive/HD externo + ZIP versionado) e dump do banco de staging via
`supabase db dump --linked` (schema E dados, em arquivos separados — corrigido no R-003:
o default da CLI é **só schema**; os dados saem com `--data-only`). Sincronização
Git fica desligada por padrão (`-SincronizarGit` liga) — este projeto só commita em cima de
portão validado, backup automático não deve commitar trabalho pela metade.

Copie `config/paths.json.example` para `config/paths.json` (gitignored) e ajuste os caminhos
reais de OneDrive/HD externo/snapshots antes do primeiro uso; sem esse arquivo a rotina usa
defaults razoáveis (OneDrive detectado por variável de ambiente).

**A partir do M18/M19, o dump do banco de staging contém dado real do cliente-piloto** (Mania
de Modas: CNPJ, IE, e-mail do responsável) — tratar como sensível, nunca versionar/anexar em
canal comum, mesmo rotulado "staging". Restauração remota (seção abaixo) continua exigindo
portão separado — a rotina automatizada só cobre a geração do backup, não a restauração.

## RPO / RTO (definidos no R-003, 28/09/2026)

- **RPO: 24 horas** — a rotina é manual e **nunca rodou neste clone** (verificado em
  28/09/2026: sem `config/paths.json`, sem `logs/.../backup.log`, sem dumps em
  `..\Backups\Snapshots`). Não há agendador autorizado (não criar tarefa do Windows fora
  da pasta do projeto). Operação: rodar
  `powershell -File .\scripts\backup-connectioncyber-staging.ps1` ao fim de cada dia de
  trabalho ⇒ perda máxima aceitável = 1 dia de trabalho.
- **RTO: 4 horas** (teto contratual) / **medido: 8,4 segundos** de restore puro — prova
  executada em 28/09/2026 (ver abaixo). O RTO realista é o tempo total do procedimento:
  baixar dump do HD/OneDrive + subir ambiente isolado + restore + validações ≈ 15 minutos.
- Backup anterior ao corte identificado por referência opaca e hash.
- Restauração primeiro em destino isolado, nunca sobre o banco ativo.
- Validação de versão, migrations, RLS, contagens, checksums e smoke tests.

## Prova de restauração (R-003) — executada e PASS

Comando (reprodutível, destrói o laboratório no fim; `-Manter` inspeciona):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-restore-r003.ps1
```

O que o script faz: gera dump schema + `--data-only` do staging (`%TEMP%\connectioncyber-r003\`),
sobe container **isolado** `public.ecr.aws/supabase/postgres:17.6.1.155` (mesma versão 17.6 do
staging, porta 55432), prepara roles (`anon`, `authenticated`, `service_role`), restaura
schema + dados e valida **21 checks**.

Resultado de 28/09/2026 (relatório `%TEMP%\connectioncyber-r003\r003-report-20260928-235947.txt`):

- **21/21 checks PASS**;
- assinatura md5 do schema (tabelas+colunas+funções+policies+RLS de `public`/`erp_security`)
  **idêntica**: `88a6466c77dec3e609098e49f9b62295`;
- contagens idênticas: 232 tabelas, 2.342 colunas, 101 funções, 396 policies, 232 com RLS,
  5 tenants, 12 usuários, 25 capabilities;
- seed M25 (plano `padrao` R$199 placeholder, 13 capabilities) e grant `anon` de SELECT
  em `saas_plans` presentes;
- **RTO medido: 8,4 s** (schema 8,0 s + dados 0,5 s) + ~40 s do script inteiro;
- hashes dos dumps usados: schema
  `5A265EBF24AE29F8D773A49660F028DB2605165B49568345E5BB847B2F5BE224`,
  dados `2C6E48A968F5AA00FA3A2DAC1CDF89E029EB212B9710EDF2CA9EF3141C4E94C6`.

### Perímetro e limitações do backup (definido no R-003)

- **Coberto**: schema `public` + `erp_security` (schema e dados) — o perímetro do app.
- **Fora do perímetro (serviço gerenciado pelo Supabase)**: schemas `auth`/`storage`.
  - `auth.uid()` etc. já existem no Postgres gerenciado; INSERTs de `auth`/`storage`
    são descartados do dump de dados (drift de versão do GoTrue quebraria o restore).
  - Policies do projeto sobre `storage.objects` e o trigger `on_auth_user_created`
    **não vêm no dump** — são recriados pelas migrations no ambiente alvo
    (a migration é a fonte de verdade nesses schemas; ver 0045).
- ⚠️ **Nunca** restaurar com `drop schema auth cascade` num restore parcial: em cascata
  ele remove policies de `public` dependentes de `auth.uid()` (perda silenciosa de RLS —
  causa de falha encontrada e eliminada na prova).
- Restauração usa `docker cp` + `psql -f` (não pipe): o pipe do PowerShell converte para
  o encoding do console e corrompe acentos, invalidando a assinatura.

## Sequência

1. registrar janela, responsáveis, origem e destino;
2. confirmar backup e hash sem copiar segredo para o projeto;
3. restaurar em ambiente isolado (`verify-restore-r003.ps1` é o molde);
4. executar validações e medir duração;
5. registrar go/no-go e destruir o laboratório somente após aceite.

Falha em qualquer etapa implica `NO-GO`; restauração em produção exige portão separado.
