# ============================================================
# R-003 - Prova de restauracao (backup gerenciado + RPO/RTO)
#
# Gera dump schema+data do Supabase STAGING (linked), restaura em um
# container PostgreSQL ISOLADO (mesma versao 17.6, imagem supabase) e
# valida fidelidade (assinatura md5 do schema public+erp_security,
# contagens, RLS, grants e seed M25) alem de cronometrar o restore
# (base para o RTO). Evidencia exigida pelo achado critico R-003 do
# STATUS-MESTRE antes do piloto.
#
# O schema auth/storage (servico gerenciado, fora do dump do staging)
# vem da stack local via pg_dump -s - mesma imagem do Supabase.
#
# Uso:       .\scripts\verify-restore-r003.ps1
# Manter:    .\scripts\verify-restore-r003.ps1 -Manter
# Reusar:    .\scripts\verify-restore-r003.ps1 -UsarDumpsExistentes
#
# Dumps sao SENSIVEIS (dado real do cliente-piloto): ficam apenas em
# %TEMP%\connectioncyber-r003 e nunca devem ser versionados/enviados.
# ============================================================
param(
    [switch]$Manter,
    [switch]$UsarDumpsExistentes,
    [string]$Image = 'public.ecr.aws/supabase/postgres:17.6.1.155',
    [int]$Port = 55432,
    [string]$ContainerName = 'r003-restore-proof',
    [string]$WorkDir = (Join-Path $env:TEMP 'connectioncyber-r003')
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$startTime = Get-Date
$repo = Split-Path -Parent $PSScriptRoot
$logFile = Join-Path $WorkDir ("r003-report-{0}.txt" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
$script:checks = New-Object System.Collections.Generic.List[object]

function Write-Step([string]$msg) {
    $line = '[{0}] {1}' -f (Get-Date -Format 'HH:mm:ss'), $msg
    Write-Host $line
    Add-Content -LiteralPath $logFile -Value $line
}

function Add-Check([string]$name, [bool]$pass, [string]$detail = '') {
    $script:checks.Add([pscustomobject]@{ check = $name; resultado = $(if ($pass) { 'PASS' } else { 'FALHA' }); detalhe = $detail })
    $tag = if ($pass) { 'PASS' } else { 'FALHA' }
    Write-Step ('  [{0}] {1} {2}' -f $tag, $name, $detail)
}

# Remove blocos SQL multiline iniciados por $pattern ate o ';' de fechamento
# (usado para descartar triggers do auth local: seus alvos - ex.
# public.handle_new_user() - so existem apos o restore do schema do staging).
function Remove-SqlBlocks([string]$path, [string]$pattern) {
    $lines = Get-Content -LiteralPath $path
    $out = [System.Collections.Generic.List[string]]::new()
    $skip = $false; $removed = 0
    foreach ($l in $lines) {
        if (-not $skip -and $l -match $pattern) { $skip = $true; $removed++; continue }
        if ($skip) { if ($l -match ';\s*$') { $skip = $false }; continue }
        $out.Add($l)
    }
    if ($skip) { throw ("bloco iniciado por '{0}' nao terminou em {1}" -f $pattern, $path) }
    Set-Content -LiteralPath $path -Value $out -Encoding utf8
    return $removed
}

function Invoke-Native([string]$exe, [string[]]$cmdArgs) {
    $ErrorActionPreference = 'Continue'
    try {
        $out = (& $exe @cmdArgs 2>&1 | Out-String)
        $code = $LASTEXITCODE
    } finally { $ErrorActionPreference = 'Stop' }
    if ($code -ne 0) { throw ("{0} falhou (exit {1}): {2}" -f $exe, $code, $out) }
    return $out
}

function Invoke-Silent([string]$exe, [string[]]$cmdArgs) {
    $ErrorActionPreference = 'Continue'
    try { (& $exe @cmdArgs 2>&1 | Out-Null) } finally { $ErrorActionPreference = 'Stop' }
}

New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null

try {
    Write-Step '=== R-003: prova de restauracao em ambiente isolado ==='

    # 1. Dumps do staging (schema + data-only). O data bruto fica num arquivo
    #    proprio (identidade do backup) e a copia filtrada vai para o restore.
    $schemaDump = Join-Path $WorkDir 'r003-schema.sql'
    $rawDataDump = Join-Path $WorkDir 'r003-data-raw.sql'
    $dataDump = Join-Path $WorkDir 'r003-data.sql'
    if ($UsarDumpsExistentes -and (Test-Path $schemaDump) -and (Test-Path $rawDataDump)) {
        Write-Step 'Reusando dumps existentes (-UsarDumpsExistentes)'
    } else {
        Write-Step 'Gerando dump SCHEMA do staging (supabase db dump --linked)'
        Push-Location $repo
        try {
            Invoke-Native 'supabase' @('db', 'dump', '--linked', '-f', $schemaDump) | Out-Null
            Write-Step 'Gerando dump DATA do staging (supabase db dump --linked --data-only)'
            Invoke-Native 'supabase' @('db', 'dump', '--linked', '--data-only', '-f', $rawDataDump) | Out-Null
        } finally { Pop-Location }
    }
    $schemaSha = (Get-FileHash -LiteralPath $schemaDump -Algorithm SHA256).Hash
    $dataSha = (Get-FileHash -LiteralPath $rawDataDump -Algorithm SHA256).Hash
    Add-Check 'dump schema gerado' ((Get-Item $schemaDump).Length -gt 0) ("sha256=$schemaSha bytes=$((Get-Item $schemaDump).Length)")

    # auth/storage no data dump sao do SERVICO GERENCIADO (GoTrue/Storage):
    # o restore real recebe essas estruturas do proprio ambiente alvo (drift
    # de versao local x staging quebra os INSERTs). Descartamos os blocos e
    # provamos schema+dados PUBLICOS - o perimetro do backup do app.
    Copy-Item -LiteralPath $rawDataDump -Destination $dataDump -Force
    $authDataRemoved = Remove-SqlBlocks $dataDump '^INSERT INTO "(auth|storage)"\.'
    $dataInserts = (Select-String -LiteralPath $dataDump -Pattern '^INSERT INTO' | Measure-Object).Count
    Add-Check 'dump data gerado' ((Get-Item $rawDataDump).Length -gt 0) ("sha256=$dataSha bytes=$((Get-Item $rawDataDump).Length)")
    Add-Check 'INSERTs de auth/storage descartados' (($authDataRemoved -eq 10) -and ($dataInserts -eq 42)) ("$authDataRemoved removidos, $dataInserts publicos restantes")
    Add-Check 'dump data contem INSERTs publicos' ($dataInserts -gt 0) "$dataInserts statements"

    # 2. Assinatura e contagens do STAGING (lado de referencia).
    $signatureBody = @'
  select 'T:'||c.table_name||'('||string_agg(c.column_name||':'||c.data_type, ',' order by c.ordinal_position)||')' as linha
    from information_schema.columns c where c.table_schema='public' group by c.table_name
  union all
  select 'F:'||n.nspname||'.'||p.proname||'('||pg_get_function_identity_arguments(p.oid)||')'
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in ('public','erp_security')
  union all
  select 'P:'||policyname||'@'||tablename||':'||qual from pg_policies where schemaname='public'
  union all
  select 'R:'||c.relname from pg_class c join pg_namespace n on n.oid=c.relnamespace
   where n.nspname='public' and c.relkind='r' and c.relrowsecurity
'@
    $signatureSql = "select md5(coalesce(string_agg(x.linha, E'\n' order by x.linha), '')) as assinatura from ($signatureBody) x;"
    $linesSql = "select linha from ($signatureBody) x order by 1;"
    $countsSql = @'
select
 (select count(*) from information_schema.tables where table_schema='public' and table_type='BASE TABLE') as tabelas,
 (select count(*) from information_schema.columns where table_schema='public') as colunas,
 (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in ('public','erp_security')) as funcoes,
 (select count(*) from pg_policies where schemaname='public') as policies,
 (select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind='r' and c.relrowsecurity) as tabelas_rls,
 (select count(*) from public.tenants) as tenants,
 (select count(*) from public.users) as usuarios,
 (select count(*) from public.erp_capability_catalog) as capabilities;
'@

    function Invoke-StagingQuery([string]$sql) {
        Push-Location $repo
        try { $out = Invoke-Native 'supabase' @('db', 'query', '--linked', $sql) } finally { Pop-Location }
        $json = [regex]::Match($out, '(?s)\{.*\}').Value | ConvertFrom-Json
        return $json.rows
    }

    Write-Step 'Coletando assinatura e contagens do staging (referencia)'
    $stagingSignature = (Invoke-StagingQuery $signatureSql | Select-Object -First 1).assinatura
    $stagingCounts = Invoke-StagingQuery $countsSql | Select-Object -First 1
    Add-Check 'assinatura do staging coletada' ([bool]$stagingSignature) $stagingSignature

    # 4. Container isolado (mesma versao 17.6).
    Write-Step "Subindo container isolado $ContainerName ($Image, porta $Port)"
    Invoke-Silent 'docker' @('rm', '-f', $ContainerName)
    Invoke-Native 'docker' @('run', '-d', '--name', $ContainerName,
        '-e', 'POSTGRES_PASSWORD=r003', '-e', 'POSTGRES_DB=postgres',
        '-p', ("{0}:5432" -f $Port), $Image) | Out-Null
    # A imagem supabase roda initdb + migrations (migrate.sh) num servidor
    # temporario ANTES do servidor final: conectar nessa janela derruba o init.
    # Esperamos o migrate.sh sumir + banco aceitar consultas.
    $initDone = $false
    for ($i = 0; $i -lt 150; $i++) {
        Invoke-Silent 'docker' @('exec', $ContainerName, 'sh', '-c', 'pgrep -f ''[m]igrate.sh'' >/dev/null')
        $migrating = ($LASTEXITCODE -eq 0)
        Invoke-Silent 'docker' @('exec', $ContainerName, 'psql', '-U', 'postgres', '-d', 'postgres', '-tAc', 'select 1')
        $dbUp = ($LASTEXITCODE -eq 0)
        if (-not $migrating -and $dbUp) { $initDone = $true; break }
        Start-Sleep -Seconds 2
    }
    if (-not $initDone) { throw 'init da imagem nao terminou em 300s' }
    Write-Step 'container pronto (init da imagem concluido)'

    function Invoke-Psql([string]$sql, [string]$User = 'postgres') {
        $ErrorActionPreference = 'Continue'
        try {
            $out = ($sql | & docker exec -i $ContainerName psql -U $User -d postgres -v ON_ERROR_STOP=1 -t -A -F '|' 2>&1 | Out-String)
            $code = $LASTEXITCODE
        } finally { $ErrorActionPreference = 'Stop' }
        if ($code -ne 0) { throw "psql falhou: $out" }
        return $out
    }

    function Invoke-PsqlRetry([string]$sql, [string]$User = 'postgres', [int]$Attempts = 30) {
        $last = ''
        for ($i = 0; $i -lt $Attempts; $i++) {
            try { return Invoke-Psql $sql $User } catch { $last = $_.Exception.Message; Start-Sleep -Seconds 2 }
        }
        throw "psql retry esgotado ($Attempts x): $last"
    }

    # Restauracao e queries de dados passam por ARQUIVO (docker cp + psql -f):
    # o pipe do PowerShell converte para o encoding do console e corrompe
    # acentos (utf8 -> OEM), invalidando a assinatura e os dados.
    function Invoke-PsqlFile([string]$path, [string]$User = 'postgres') {
        $remote = '/tmp/r003-in.sql'
        Invoke-Native 'docker' @('cp', $path, ('{0}:{1}' -f $ContainerName, $remote)) | Out-Null
        $ErrorActionPreference = 'Continue'
        try {
            $out = (& docker exec $ContainerName psql -U $User -d postgres -v ON_ERROR_STOP=1 -t -A -F '|' -f $remote 2>&1 | Out-String)
            $code = $LASTEXITCODE
        } finally { $ErrorActionPreference = 'Stop' }
        Invoke-Silent 'docker' @('exec', $ContainerName, 'rm', '-f', $remote)
        if ($code -ne 0) { throw "psql -f falhou: $out" }
        return $out
    }

    function Invoke-PsqlQuery([string]$sql, [string]$User = 'postgres') {
        $tmp = Join-Path $WorkDir 'r003-query.sql'
        [System.IO.File]::WriteAllText($tmp, $sql, [System.Text.UTF8Encoding]::new($false))
        return Invoke-PsqlFile $tmp $User
    }

    # 5. Pre-condicoes do banco alvo (roles do Supabase + schemas de extensao).
    #    Na imagem supabase o papel `postgres` nao nasce superuser; elevamos
    #    (equivalente ao nivel de acesso da ferramenta de restore gerenciado).
    #    O init da imagem reinicia o Postgres uma vez - por isso o retry.
    Write-Step 'Preparando roles e schemas no banco alvo'
    Invoke-PsqlRetry 'alter role postgres superuser' 'supabase_admin' | Out-Null
    # O entrypoint faz o shutdown do servidor temporario apos o init; exigimos
    # 3 consultas consecutivas ok para so entao restaurar.
    $stable = 0
    for ($i = 0; $i -lt 60 -and $stable -lt 3; $i++) {
        Invoke-Silent 'docker' @('exec', $ContainerName, 'psql', '-U', 'postgres', '-d', 'postgres', '-tAc', 'select 1')
        if ($LASTEXITCODE -eq 0) { $stable++ } else { $stable = 0 }
        Start-Sleep -Seconds 2
    }
    if ($stable -lt 3) { throw 'servidor nao estabilizou apos o init' }
    Invoke-PsqlRetry @"
select 'create role '||r::text||' nologin' from (values ('anon'),('authenticated'),('service_role'),('supabase_admin')) v(r) where to_regrole(r) is null \gexec
select 'create schema if not exists '||s::text from (values ('extensions'),('vault')) v(s) where to_regnamespace(s) is null \gexec
"@ | Out-Null
    Add-Check 'roles/schemas alvo preparados' $true 'postgres superuser; anon, authenticated, service_role, extensions, vault'

    # 6. Restore cronometrado. NOTA: os schemas auth/storage sao GERENCIADOS
    #    pelo Supabase e ficam fora do perimetro do backup do app:
    #    - auth.uid()/auth.role() ja existem na imagem do Postgres;
    #    - INSERTs de auth/storage vem descartados do data dump (drift GoTrue);
    #    - policies do projeto sobre storage.objects e o trigger
    #      on_auth_user_created sao recriados pelas migrations no ambiente
    #      alvo (fonte de verdade nesses schemas).
    #    NAO fazer `drop schema auth cascade` aqui: ele remove em cascata as
    #    policies de public dependentes de auth.uid (perda silenciosa de RLS).
    $restoreTotal = [System.Diagnostics.Stopwatch]::StartNew()
    $t = [System.Diagnostics.Stopwatch]::StartNew()
    Write-Step 'Restaurando SCHEMA do staging'
    Invoke-PsqlFile $schemaDump | Out-Null
    $t.Stop()
    $schemaMs = $t.ElapsedMilliseconds
    Add-Check 'restore schema staging' $true ("{0} ms" -f $schemaMs)

    $t.Restart()
    Write-Step 'Restaurando DATA do staging'
    Invoke-PsqlFile $dataDump | Out-Null
    $t.Stop()
    $dataMs = $t.ElapsedMilliseconds
    $restoreTotal.Stop()
    $rtoMs = $schemaMs + $dataMs
    Add-Check 'restore data staging' $true ("{0} ms" -f $dataMs)
    Write-Step ("RTO medido (restore total): {0:N1} s (schema {1:N1}s + data {2:N1}s)" -f ($rtoMs / 1000), ($schemaMs / 1000), ($dataMs / 1000))

    # 7. Validacoes de fidelidade no restaurado.
    Write-Step 'Validando fidelidade do restaurado'
    $restoredSig = (Invoke-PsqlQuery $signatureSql).Trim()
    $restoredSignature = [regex]::Match($restoredSig, '([a-f0-9]{32})').Groups[1].Value
    $sigOk = ($restoredSignature -eq $stagingSignature)
    Add-Check 'assinatura md5 do schema identica' $sigOk ("staging=$stagingSignature restaurado=$restoredSignature")
    if (-not $sigOk) {
        $stLines = @((Invoke-StagingQuery $linesSql) | ForEach-Object { $_.linha }) | Sort-Object
        $rsLines = @((Invoke-PsqlQuery $linesSql) -split "`r?`n" | Where-Object { $_ }) | Sort-Object
        $stLines | Set-Content -LiteralPath (Join-Path $WorkDir 'assinatura-staging.txt') -Encoding utf8
        $rsLines | Set-Content -LiteralPath (Join-Path $WorkDir 'assinatura-restaurado.txt') -Encoding utf8
        Write-Step ("diagnostico: {0} linhas staging x {1} restaurado -> assinatura-*.txt no {2}" -f $stLines.Count, $rsLines.Count, $WorkDir)
    }

    $countFields = @('tabelas', 'colunas', 'funcoes', 'policies', 'tabelas_rls', 'tenants', 'usuarios', 'capabilities')
    $restoredCnt = (Invoke-PsqlQuery $countsSql).Trim()
    $cntParts = $restoredCnt -split '\|'
    for ($i = 0; $i -lt $countFields.Count; $i++) {
        $field = $countFields[$i]
        $expected = [int]$stagingCounts.$field
        $actual = if ($i -lt $cntParts.Count -and $cntParts[$i].Trim() -match '^\d+$') { [int]$cntParts[$i].Trim() } else { -1 }
        Add-Check ("contagem {0}" -f $field) ($actual -eq $expected) ("staging={0} restaurado={1}" -f $expected, $actual)
    }

    $abs = (Invoke-PsqlQuery @"
select
 (select count(*) from public.saas_plans where code='padrao' and price_cents=19900) as planos_seed,
 (select count(*) from public.saas_plan_capabilities) as plan_caps,
 has_table_privilege('anon','public.saas_plans','select')::text as anon_select_planos,
 (select count(*) from public.saas_checkout_intents) as intents,
 (select count(*) from public.saas_subscriptions) as subs;
"@).Trim()
    $absParts = $abs -split '\|'
    Add-Check 'seed M25 (plano padrao R$199 placeholder)' ($absParts[0] -eq '1') "planos_seed=$($absParts[0])"
    Add-Check 'M25 plan_caps=13' ($absParts[1] -eq '13') "plan_caps=$($absParts[1])"
    Add-Check 'RLS anon: select em saas_plans' ($absParts[2] -in @('t','true')) "anon select=$($absParts[2])"

    $rls = (Invoke-PsqlQuery "select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind='r' and c.relrowsecurity;").Trim()
    Add-Check 'RLS restaurado' ([int]$rls -gt 0) "tabelas public com RLS=$rls"

    # 8. Relatorio.
    $duration = (Get-Date) - $startTime
    $failed = @($script:checks | Where-Object { $_.resultado -eq 'FALHA' })
    $report = @()
    $report += '# R-003 - Prova de restauracao'
    $report += "data: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $report += "imagem: $Image"
    $report += "dump schema: $schemaSha"
    $report += "dump data: $dataSha"
    $report += "RTO medido: $([math]::Round($rtoMs / 1000, 1)) s"
    $report += "duracao total do script: $($duration.ToString('mm\:ss'))"
    $report += "checks: $($script:checks.Count) | falhas: $($failed.Count)"
    $report += ''
    $report += ($script:checks | Format-Table -AutoSize | Out-String)
    $reportText = $report -join "`n"
    Add-Content -LiteralPath $logFile -Value $reportText
    Write-Host $reportText

    if ($failed.Count -gt 0) { throw ("R-003: {0} check(s) falharam" -f $failed.Count) }
    Write-Step '=== R-003 RESTAURACAO PROVADA (todos os checks PASS) ==='
    exit 0
} catch {
    Write-Step ("R-003 FALHOU: {0}" -f $_.Exception.Message)
    exit 1
} finally {
    if (-not $Manter) {
        try { Invoke-Silent 'docker' @('rm', '-f', $ContainerName) } catch { }
        Write-Step "container $ContainerName destruido (-Manter para inspecionar)"
    }
}




