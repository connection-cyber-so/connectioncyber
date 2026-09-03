# Runbook — backup e restauração do piloto

Estado: rotina real disponível (03/09/2026) — `scripts/backup-connectioncyber-staging.ps1`,
adaptada do padrão VaultMindOS/CDP usado em outros projetos do ecossistema. Cobre código
(robocopy pra OneDrive/HD externo + ZIP versionado) e dump do banco de staging via
`supabase db dump --linked` (schema + dados, sem depender de `pg_dump` instalado). Sincronização
Git fica desligada por padrão (`-SincronizarGit` liga) — este projeto só commita em cima de
portão validado, backup automático não deve commitar trabalho pela metade.

Copie `config/paths.json.example` para `config/paths.json` (gitignored) e ajuste os caminhos
reais de OneDrive/HD externo/snapshots antes do primeiro uso; sem esse arquivo a rotina usa
defaults razoáveis (OneDrive detectado por variável de ambiente).

**A partir do M18/M19, o dump do banco de staging contém dado real do cliente-piloto** (Mania
de Modas: CNPJ, IE, e-mail do responsável) — tratar como sensível, nunca versionar/anexar em
canal comum, mesmo rotulado "staging". Restauração remota (seção abaixo) continua exigindo
portão separado — a rotina automatizada só cobre a geração do backup, não a restauração.

- RPO proposto: 15 minutos; depende de aceite e capacidade do plano.
- RTO proposto: 60 minutos; depende de teste cronometrado.
- Backup anterior ao corte identificado por referência opaca e hash.
- Restauração primeiro em destino isolado, nunca sobre o banco ativo.
- Validação de versão, migrations, RLS, contagens, checksums e smoke tests.

## Sequência

1. registrar janela, responsáveis, origem e destino;
2. confirmar backup e hash sem copiar segredo para o projeto;
3. restaurar em ambiente isolado;
4. executar validações e medir duração;
5. registrar go/no-go e destruir o laboratório somente após aceite.

Falha em qualquer etapa implica `NO-GO`; restauração em produção exige portão separado.
