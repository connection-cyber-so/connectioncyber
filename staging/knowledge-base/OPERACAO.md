# M22 — Biblioteca Técnica — Operação 0.1.1

## 1. Preparar

Executar somente na cópia staging. Node 22 é obrigatório. O Node padrão observado era 26; não ignorar o check-node-version. O ambiente deve ter npm disponível. Os comandos abaixo pressupõem que Node 22 foi selecionado no PATH da mesma janela; interrompem se o projeto detectar versão incompatível.

Auditar preflight 0043: helpers ERP, roles MFA, Storage e ausência de colisão de tabelas/bucket. Fazer backup conforme política do ambiente. Não aplicar seeds históricos, especialmente 0006, que contém dados reais. Para validação isolada usar o pacote de testes sintético.

## 2. Executar verificações locais

PowerShell, comandos completos:

~~~powershell
Set-Location -LiteralPath 'F:\Projetos\connectioncyber-staging\apps\portal'
node --version
npm.cmd test
npm.cmd run type-check
npm.cmd run lint -- --no-cache
npm.cmd run build
~~~

O build pode ler .env.local existente; usar somente configuração de staging. A execução desta entrega sobrepôs URL/chave públicas com placeholders e não precisou de dados remotos.

Banco embarcado, sem Docker, usuários ou conexões reais:

~~~powershell
Set-Location -LiteralPath 'F:\Projetos\connectioncyber-staging\packages\knowledge-base-validation'
node --version
npm.cmd ci
npm.cmd test
~~~

Documentação:

~~~powershell
Set-Location -LiteralPath 'F:\Projetos\connectioncyber-staging\apps\portal'
npm.cmd run kb:docs
npm.cmd run kb:docs:check
~~~

## 3. Estado atual do staging

Executado em 14/09/2026, somente no projeto `ozvylnaipubrmaadikvk`: preflight, dump local do esquema, dry-run e aplicação exclusiva da migration 0043. O histórico 0001–0043 ficou alinhado. Foram criadas três contas sintéticas em tenant isolado, com memberships e entitlements temporários até 21/09/2026. Os dois curadores possuem `knowledge.manage`, exigem MFA e tiveram TOTP/AAL2 verificado; o assinante não possui permissão administrativa.

As credenciais sintéticas ficam criptografadas por Windows DPAPI na pasta privada da execução e não entram no repositório, relatórios ou logs. Não reutilizar essas contas em produção. Renovar a expiração somente durante homologação autorizada.

Manter `KNOWLEDGE_BASE_ENABLED` ausente/false até concluir a jornada de Preview abaixo.

- Para assinaturas reais futuras, provisionar `kb_entitlements` somente após confirmação comercial. Não tratar matrícula histórica do site como assinatura automaticamente.
- Manter `knowledge.manage` em papel privilegiado com MFA. Preservar a revisão independente: o curador que produziu/editou conteúdo não pode liberá-lo em M4.
- Se IA for desejada, cadastrar KB_GEMINI_API_KEY e KB_GEMINI_MODEL somente no servidor. Validar o contrato de retenção do provedor e autorização de envio de conteúdo. A falta dessas configurações não impede classificação manual.
- Ativar KNOWLEDGE_BASE_ENABLED=true no portal de staging e validar o fluxo inteiro: entrada, classificação, aplicação, destino, liberação, favorito, nota, download, suspensão da assinatura e nova revisão.

O módulo não cobra, não cria assinatura no Mercado Pago e não altera webhook de matrícula. A integração comercial futura deve preencher/revogar o entitlement somente após validação server-side do evento, idempotência e reconciliação. A ausência dessa integração é explícita: o acesso começa negado.

## 4. Validar e registrar

Executar jornadas via navegador/Supabase de staging para confirmar cookies, host, MFA, RLS, Storage HTTP, URLs assinadas, consentimento Gemini, origem dos formulários e persistência. Os testes embarcados validam PostgreSQL/RLS com pré-requisitos sintéticos e helpers originais; não simulam o serviço HTTP de Storage nem o deploy Vercel.

Arquivos em quarentena: baixar para laboratório isolado; conferir SHA256 e tamanho; inspecionar malware, direitos e segredos; registrar evidência verificável; aprovar/rejeitar com outro curador. Não alegar inspeção antimalware automática.

Reservas pendentes de upload podem ser rejeitadas pelo curador. O histórico mantém o evento; limpeza física futura exige política de retenção, checkpoint e autorização. Não apagar bucket ou tabelas para resolver erro.

## 5. Reverter e liberar

Rollback operacional imediato: desativar KNOWLEDGE_BASE_ENABLED. Para interromper também RPCs diretos, usar o rollback não destrutivo fornecido, que revoga EXECUTE de kb_command. Para bloqueio de leitura de um usuário, suspender seu entitlement pelo backend autorizado. URLs assinadas já emitidas duram no máximo 60 segundos.

Reativar a permissão EXECUTE somente após correção e testes. Preferir forward-fix a DROP. Não há promoção, push, PR, merge ou deploy automático nesta entrega. Produção mantém processo próprio: revisão, backup, autorização e smoke test no domínio real.
