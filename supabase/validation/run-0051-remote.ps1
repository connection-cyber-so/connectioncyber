# M25-G0 — runner remoto (staging ozvylnaipubrmaadikvk)
#   -Phase validate : preflight + transacao 0051 com ROLLBACK + prova de residuo zero (sem escrita persistente)
#   -Phase apply    : dry-run + db push (se 0051 ainda nao estiver no historico) + verificacoes
#   -Phase verify   : somente pos-apply (38/38 + 28/28, regressao M24 36/36 + 25/25, REST anon) — idempotente
#   -Phase all      : validate + apply
# Requer: `supabase login --token sbp_...` ja executado.
[CmdletBinding()]
param(
  [ValidateSet('validate','apply','verify','all')]
  [string]$Phase = 'validate',
  [string]$Ref = 'ozvylnaipubrmaadikvk'
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$logDir = Join-Path $repo 'staging\logs'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$script:log = Join-Path $logDir ("m25-g0-remote-{0}-{1}.log" -f $stamp, $Phase)
$script:results = @()

function Write-Log([string]$msg, [string]$level = 'INFO') {
  $line = '{0} [{1}] {2}' -f (Get-Date -Format 'HH:mm:ss'), $level, $msg
  Write-Host $line
  Add-Content -LiteralPath $script:log -Value $line
}

function Invoke-Sup([string]$name, [string[]]$cliArgs, [string]$expect, [switch]$AllowFail) {
  Write-Log ("### {0} :: supabase {1}" -f $name, ($cliArgs -join ' '))
  $output = (& supabase @cliArgs 2>&1 | Out-String)
  $exit = $LASTEXITCODE
  Add-Content -LiteralPath $script:log -Value $output
  $ok = ($exit -eq 0)
  if ($ok -and $expect) { $ok = $output -like ('*' + $expect + '*') }
  if (-not $ok) {
    if ($AllowFail) {
      Write-Log ("ESPERADO-FALHA: {0}" -f $name) 'AVISO'
      $script:results += [pscustomobject]@{ passo = $name; status = 'falha-esperada'; marcador = $expect }
      return $output
    }
    Write-Log ("FALHOU (exit={0}): {1}" -f $exit, $name) 'ERRO'
    Add-Content -LiteralPath $script:log -Value $output
    throw ("passo falhou: {0}" -f $name)
  }
  Write-Log ("OK: {0}" -f $name)
  $script:results += [pscustomobject]@{ passo = $name; status = 'ok'; marcador = $expect }
  return $output
}

function Get-SiteEnv([string]$key) {
  $file = Join-Path $repo 'apps\site\.env.local'
  $line = Get-Content -LiteralPath $file | Where-Object { $_ -match ('^' + $key + '=') } | Select-Object -First 1
  if (-not $line) { throw ("chave {0} ausente em apps\site\.env.local" -f $key) }
  $prefix = $key + '='
  if (-not $line.StartsWith($prefix)) { throw ("linha nao inicia com {0}" -f $prefix) }
  return $line.Substring($prefix.Length).Trim().Trim('"', "'")
}

function Assert-PgTap([string]$name, [string]$output, [int]$plan) {
  if ($output -like '*Looks like*') {
    $m = [regex]::Match($output, '"resultado":\s*"(?:[^"\\]|\\.)*"')
    throw ('pgTAP falhou em {0}: {1}' -f $name, $m.Value)
  }
  if ($output -notlike '*"resultado": null*') { throw ('resultado do pgTAP ausente em {0}' -f $name) }
  Write-Log ('{0}: finish() sem relato de falha => plano {1} executado integralmente' -f $name, $plan)
  $script:results += [pscustomobject]@{ passo = $name; status = ('ok ({0}/{1})' -f $plan, $plan); marcador = ('1..{0}' -f $plan) }
}

# A Management API devolve apenas o ultimo result set com linhas: o arquivo de teste
# termina em `select * from finish();` (0 linhas) + rollback, entao materializa uma copia
# agregada em %TEMP% para conseguir ler o resultado do pgTAP.
function New-PgTapWrapped([string]$source, [string]$label) {
  $sql = Get-Content -LiteralPath $source -Raw
  $sql = $sql -replace 'select\s+\*\s+from\s+finish\(\);', "select string_agg(f.result, E'\n') as resultado, count(*) filter (where f.result like 'not ok%') as falhas from finish() as f(result);"
  if ($sql -notlike '*string_agg(f.result*') { throw ("nao consegui agregar finish() em {0}" -f $source) }
  $dest = Join-Path $env:TEMP ('m25-{0}-{1}.sql' -f $label, (Get-Date -Format 'yyyyMMddHHmmss'))
  Set-Content -LiteralPath $dest -Value $sql -Encoding utf8 -NoNewline
  return $dest
}

function Invoke-AnonymousRest {
  $url = Get-SiteEnv 'NEXT_PUBLIC_SUPABASE_URL'
  $key = Get-SiteEnv 'NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY'
  $tables = @('courses', 'products', 'cms_content', 'saas_plans')
  $rows = @()
  foreach ($t in $tables) {
    $uri = "$url/rest/v1/$($t)?select=id&limit=1"
    try {
      $resp = Invoke-WebRequest -Uri $uri -Headers @{ apikey = $key; 'Accept-Profile' = 'public' } -SkipHttpErrorCheck -TimeoutSec 30
      $body = [string]$resp.Content
      $rows += [pscustomobject]@{ tabela = $t; status = [int]$resp.StatusCode; erro42501 = ($body -like '*42501*') }
    } catch {
      $rows += [pscustomobject]@{ tabela = $t; status = 'erro-conexao'; erro42501 = $false; detalhe = $_.Exception.Message }
    }
  }
  return $rows
}

$preflight = Join-Path $repo 'supabase\preflight\0051_m25_saas_billing_subscriptions_preflight.sql'
$txn = Join-Path $repo 'supabase\validation\0051_transaction.generated.sql'
$post = Join-Path $repo 'supabase\verification\0051_post_apply.sql'
$test38 = Join-Path $repo 'supabase\tests\0051_m25_saas_billing_subscriptions.test.sql'
$test28 = Join-Path $repo 'supabase\tests\0051_m25_saas_billing_subscriptions.adversarial.test.sql'
$reg36 = Join-Path $repo 'supabase\tests\0050_m24_accountant_delivery.test.sql'
$reg25 = Join-Path $repo 'supabase\tests\0050_m24_accountant_delivery.adversarial.test.sql'
foreach ($f in @($preflight, $txn, $post, $test38, $test28, $reg36, $reg25)) {
  if (-not (Test-Path -LiteralPath $f)) { throw ("artefato ausente: {0}" -f $f) }
}
$sha = (Get-FileHash -LiteralPath $txn -Algorithm SHA256).Hash
Write-Log ("log={0}" -f $script:log)
Write-Log ("SHA256 transacao={0}" -f $sha)

Write-Log '=== 0. autenticacao e vinculo ==='
$auth = (& supabase db query --linked "select 'M25_G0_AUTH_OK' as ok" 2>&1 | Out-String)
if ($LASTEXITCODE -ne 0 -or $auth -notlike '*M25_G0_AUTH_OK*') {
  Add-Content -LiteralPath $script:log -Value $auth
  Write-Log 'NAO AUTENTICADO/VINCULADO. Rode: supabase login --token sbp_... e reexecute.' 'ERRO'
  throw 'supabase nao autenticado'
}
Write-Log 'autenticado e vinculado'
$linkFile = Join-Path $repo 'supabase\.temp\linked-project.json'
if (Test-Path -LiteralPath $linkFile) {
  $link = Get-Content -LiteralPath $linkFile -Raw | ConvertFrom-Json
  if ($link.ref -ne $Ref) { throw ("projeto vinculado ({0}) difere de {1}" -f $link.ref, $Ref) }
  Write-Log ("projeto vinculado: {0} ({1})" -f $link.ref, $link.name)
}
Invoke-Sup 'dry-run historico' @('db', 'query', '--linked',
  "select string_agg(version,',' order by version) as versoes from supabase_migrations.schema_migrations") | Out-Null

if ($Phase -in @('validate', 'all')) {
  Write-Log '=== FASE VALIDATE (rollback, sem escrita persistente) ==='
  $restAntes = Invoke-AnonymousRest
  $restAntes | Format-Table -AutoSize | Out-String | ForEach-Object { Write-Log $_.TrimEnd() }
  $restAntes | ConvertTo-Json -Compress | Add-Content -LiteralPath $script:log

  Invoke-Sup 'preflight 1/2' @('db', 'query', '--linked', '-f', $preflight) 'M25_PREFLIGHT_OK' | Out-Null
  $txnOut = Invoke-Sup 'transacao 66/66 com rollback' @('db', 'query', '--linked', '-f', $txn) 'M25_0051_TRANSACTION_66_OF_66_ROLLBACK'
  if ($txnOut -match 'M25_0051_PGTAP_FAILED') { throw 'pgTAP reportou falha na transacao' }
  Write-Log 'pgTAP remoto: 66/66 (finish() nao lancou excecao; marcador de rollback emitido)'
  $script:results += [pscustomobject]@{ passo = 'pgTAP transacao remota'; status = 'ok (66/66)'; marcador = '66/66' }
  Invoke-Sup 'preflight 2/2 (prova de residuo zero)' @('db', 'query', '--linked', '-f', $preflight) 'M25_PREFLIGHT_OK' | Out-Null
  Invoke-Sup '0051 ausente do historico' @('db', 'query', '--linked',
    "select count(*) as tem_0051 from supabase_migrations.schema_migrations where version='0051'") '"tem_0051": 0' | Out-Null
}

if ($Phase -in @('apply', 'all')) {
  Write-Log '=== FASE APPLY (persistente) ==='
  $histAntes = Invoke-Sup 'historico antes do push' @('db', 'query', '--linked',
    "select string_agg(version,',' order by version) as versoes from supabase_migrations.schema_migrations")
  if ($histAntes -match '\b0051\b') {
    Write-Log '0051 ja consta no historico remoto: db push dispensado'
    $script:results += [pscustomobject]@{ passo = 'db push'; status = 'ja-aplicada'; marcador = '0051' }
  } else {
    $dry = Invoke-Sup 'push dry-run' @('db', 'push', '--dry-run') '0051_m25_saas_billing_subscriptions'
    $names = @([regex]::Matches($dry, '\b\d{4}_[a-z0-9_]+') | ForEach-Object { $_.Value } | Sort-Object -Unique)
    $extras = @($names | Where-Object { $_ -ne '0051_m25_saas_billing_subscriptions' })
    if ($names.Count -eq 0) { throw 'dry-run nao listou migrations pendentes' }
    if ($extras.Count -gt 0) { throw ('dry-run quer aplicar migrations extras: ' + ($extras -join ',')) }
    Write-Log 'dry-run seleciona exclusivamente 0051_m25_saas_billing_subscriptions'
    Invoke-Sup 'db push (aplica 0051)' @('db', 'push', '--yes') | Out-Null
  }
}

if ($Phase -in @('apply', 'verify', 'all')) {
  Write-Log '=== VERIFICACAO POS-APPLY ==='
  Invoke-Sup 'pos-apply verificacao' @('db', 'query', '--linked', '-f', $post) 'M25_POST_APPLY_OK' | Out-Null
  $t38file = New-PgTapWrapped -source $test38 -label 'test38'
  $t38 = Invoke-Sup 'testes 38/38' @('db', 'query', '--linked', '-f', $t38file) 'resultado'
  Assert-PgTap -name 'testes 38/38' -output $t38 -plan 38
  $t28file = New-PgTapWrapped -source $test28 -label 'test28'
  $t28 = Invoke-Sup 'testes adversariais 28/28' @('db', 'query', '--linked', '-f', $t28file) 'resultado'
  Assert-PgTap -name 'testes adversariais 28/28' -output $t28 -plan 28
  $r36file = New-PgTapWrapped -source $reg36 -label 'reg0050'
  $r36 = Invoke-Sup 'regressao M24 estrutural 36/36' @('db', 'query', '--linked', '-f', $r36file) 'resultado'
  Assert-PgTap -name 'regressao M24 estrutural 36/36' -output $r36 -plan 36
  $r25file = New-PgTapWrapped -source $reg25 -label 'reg0050adv'
  $r25 = Invoke-Sup 'regressao M24 adversarial 25/25' @('db', 'query', '--linked', '-f', $r25file) 'resultado'
  Assert-PgTap -name 'regressao M24 adversarial 25/25' -output $r25 -plan 25
  Invoke-Sup 'preflight agora deve recusar (ja aplicada)' @('db', 'query', '--linked', '-f', $preflight) -AllowFail | Out-Null
  Invoke-Sup 'historico final' @('db', 'query', '--linked',
    "select string_agg(version,',' order by version) as versoes from supabase_migrations.schema_migrations") | Out-Null

  $restDepois = Invoke-AnonymousRest
  $restDepois | Format-Table -AutoSize | Out-String | ForEach-Object { Write-Log $_.TrimEnd() }
  $restDepois | ConvertTo-Json -Compress | Add-Content -LiteralPath $script:log
  $falhas = @($restDepois | Where-Object { $_.status -ne 200 -or $_.erro42501 })
  if ($falhas.Count -gt 0) { throw ('REST anon ainda falha: ' + (($falhas | ForEach-Object { $_.tabela }) -join ',')) }
  Write-Log 'REST anon: courses/products/cms_content/saas_plans = 200 sem 42501'
}

Write-Log '=== RESUMO ==='
$results | Format-Table -AutoSize | Out-String | ForEach-Object { Write-Log $_.TrimEnd() }
Write-Log ("FIM: {0} passos | log {1}" -f $results.Count, $script:log)
Write-Output $script:log
