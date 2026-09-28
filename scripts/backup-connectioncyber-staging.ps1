# ============================================================
# ConnectionCyber (staging) - Backup Manager v1.0
# Adaptado de backup-portal-teologico.ps1 (mesmo padrao VaultMindOS/CDP)
# pra este monorepo, que tem duas diferencas estruturais reais:
#
#  1. "staging" nao e um projeto/repositorio proprio - e uma branch
#     deste mesmo clone dentro do repo connection-cyber-so/connectioncyber.
#     O git-sync nao cria remote nenhum: aponta pra esse repo, branch
#     staging, e fica DESLIGADO por padrao (-SincronizarGit liga) porque
#     este projeto so commita em cima de portao validado (ver
#     GOVERNANCA-EXECUCAO-AUTOMATICA.md) - um backup automatico nao deve
#     commitar trabalho pela metade por cima disso.
#  2. O dump do banco usa a Supabase CLI (`supabase db dump --linked`),
#     ja autenticada neste projeto pra staging (ozvylnaipubrmaadikvk) -
#     nao pg_dump avulso. Evita depender de instalar as ferramentas de
#     cliente do PostgreSQL so pra isto.
#
# Fluxo:
# 1. Validar ambiente local
# 2. Sincronizar OneDrive (codigo)
# 3. Sincronizar HD externo (codigo)
# 4. Gerar snapshot ZIP versionado (codigo)
# 5. Gerar dump do banco Supabase staging (schema+dados) via
#    `supabase db dump --linked` e copiar pra Snapshots, OneDrive/database
#    e HD externo/database
# 6. Commit + Push da branch staging (SOMENTE codigo, e SOMENTE se
#    -SincronizarGit for passado - o dump do banco NUNCA e commitado)
# 7. Registrar log operacional
#
# Uso manual:        .\scripts\backup-connectioncyber-staging.ps1
# Uso silencioso:     .\scripts\backup-connectioncyber-staging.ps1 -Silencioso
# Apenas validar:     .\scripts\backup-connectioncyber-staging.ps1 -DryRun
# Pular banco:        .\scripts\backup-connectioncyber-staging.ps1 -PularBanco
# Commitar tambem:    .\scripts\backup-connectioncyber-staging.ps1 -SincronizarGit
#
# Pre-requisito da etapa 5: `npx supabase` autenticado e com este projeto
# linkado pra staging (ja e o caso neste clone - confirme com
# `npx supabase projects list` se tiver dúvida).
#
# ATENCAO: a partir do M18/M19 deste projeto, o Supabase de staging
# passou a guardar dado real de cliente-piloto (Mania de Modas: CNPJ, IE,
# e-mail do responsavel). O dump do banco gerado aqui contem esse dado -
# trate como sensivel exatamente como um dump de producao, mesmo estando
# rotulado "staging". Nunca versionar, nunca anexar em chat/e-mail comum.
# ============================================================

param(
    [switch]$Silencioso,
    [switch]$DryRun,
    [switch]$PularBanco,
    [switch]$SincronizarGit,
    [string]$CommitMessage
)

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $false
$StartTime = Get-Date

$ProjectName = "connectioncyber-staging"
$ProjectDisplayName = "ConnectionCyber (staging)"
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptRoot
$ConfigPath = Join-Path $ProjectRoot "config\paths.json"

# Diferente do script de origem: se config/paths.json nao existir, usa
# defaults razoaveis em vez de falhar. OneDrive detectado pela variavel
# de ambiente que o Windows ja define quando o OneDrive esta instalado;
# HD externo e snapshots caem em pastas locais previsiveis, que o
# Sync-Robocopy abaixo ja sabe pular graciosamente se o disco nao existir.
$DefaultConfig = [pscustomobject]@{
    onedrive              = if ($env:OneDrive) { Join-Path $env:OneDrive "Backups" } else { Join-Path $env:USERPROFILE "OneDrive\Backups" }
    external              = "E:\Backups"
    snapshots             = Join-Path $ProjectRoot "..\Backups\Snapshots"
    github                = [pscustomobject]@{ organization = "connection-cyber-so"; defaultBranch = "staging" }
    excludedDirectories   = @("node_modules", ".next", ".vercel", ".git", ".turbo", "logs")
    excludedFiles         = @("*.log", "*.env.local", "*.pfx")
}

if (Test-Path $ConfigPath) {
    $Config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
} else {
    $Config = $DefaultConfig
}

function Join-PathSafe {
    param([string]$Base, [string]$Child)
    return ($Base.TrimEnd('\', '/') + '\' + $Child)
}

$Origem = $ProjectRoot
$OneDriveDestino = Join-Path $Config.onedrive $ProjectName
$ExternoDestino = Join-PathSafe $Config.external $ProjectName
$SnapshotDir = Join-PathSafe $Config.snapshots $ProjectName
# Repositorio real do projeto - staging e uma branch dele, nao um repo a parte.
$GitRemote = "https://github.com/connection-cyber-so/connectioncyber.git"
$BranchPadrao = "staging"
$ExcluidosDir = $Config.excludedDirectories
$ExcluidosFiles = $Config.excludedFiles

$DataHumana = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$DataArquivo = Get-Date -Format "yyyy-MM-dd_HHmmss"
$Ano = Get-Date -Format "yyyy"
$Mes = Get-Date -Format "MM"
$Usuario = $env:USERNAME

$LogRoot = Join-Path $ProjectRoot "logs\$Ano\$Mes"

function Write-Log {
    param(
        [string]$Message,
        [string]$Color = "White",
        [string]$LogType = "backup"
    )

    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [user:$Usuario] [$ProjectName] $Message"

    if (!(Test-Path $LogRoot)) {
        New-Item -ItemType Directory -Path $LogRoot -Force | Out-Null
    }

    Add-Content -Path (Join-Path $LogRoot "$LogType.log") -Value $line -Encoding UTF8

    if (-not $Silencioso) {
        Write-Host $Message -ForegroundColor $Color
    }
}

function Test-CommandExists {
    param([string]$Command)
    return [bool](Get-Command $Command -ErrorAction SilentlyContinue)
}

function Get-FreeSpaceGB {
    param([string]$Path)
    try {
        $qualifier = (Split-Path -Qualifier $Path).TrimEnd(':')
        $drive = Get-PSDrive -Name $qualifier -ErrorAction Stop
        return [math]::Round($drive.Free / 1GB, 2)
    } catch {
        return $null
    }
}

function Sync-Robocopy {
    param(
        [string]$Destino,
        [string]$NomeDestino
    )

    Write-Log "" White
    Write-Log "[COPIA] $NomeDestino -> $Destino" Yellow
    Write-Log "------------------------------------------------------------" Cyan

    $Disco = Split-Path -Qualifier $Destino
    if (!(Test-Path $Disco)) {
        Write-Log "[AVISO] Disco $Disco nao acessivel. Etapa ignorada." DarkYellow
        return
    }

    if ($DryRun) {
        Write-Log "[DRY-RUN] Copia simulada para $Destino" DarkYellow
        return
    }

    if (!(Test-Path $Destino)) {
        New-Item -ItemType Directory -Path $Destino -Force | Out-Null
        Write-Log "[OK] Pasta criada: $Destino" Green
    }

    $XD = @()
    foreach ($dir in $ExcluidosDir) { $XD += @("/XD", $dir) }

    $XF = @()
    foreach ($file in $ExcluidosFiles) { $XF += @("/XF", $file) }

    $roboArgs = @(
        $Origem,
        $Destino,
        "/MIR",
        "/R:2",
        "/W:2",
        "/NFL",
        "/NDL",
        "/NJH"
    ) + $XD + $XF

    $output = & robocopy @roboArgs
    $code = $LASTEXITCODE

    $filesLine = ($output | Where-Object { $_ -match '^\s*Files\s*:' } | Select-Object -First 1)
    if ($filesLine) {
        Write-Log "[INTEGRIDADE] $($filesLine.Trim())" DarkCyan
    }

    $freeGB = Get-FreeSpaceGB -Path $Destino
    if ($null -ne $freeGB) {
        Write-Log "[INTEGRIDADE] Espaco livre em $Disco : $freeGB GB" DarkCyan
        if ($freeGB -lt 2) {
            Write-Log "[AVISO] Espaco livre abaixo de 2 GB em $Disco" DarkYellow
        }
    }

    if ($code -le 7) {
        Write-Log "[OK] Copia concluida com robocopy codigo $code." Green
    } else {
        Write-Log "[ERRO] Robocopy retornou codigo $code." Red
        throw "Falha no robocopy para $Destino"
    }
}

function Create-ZipSnapshot {
    Write-Log "" White
    Write-Log "[ZIP] Gerando snapshot versionado (codigo)" Yellow
    Write-Log "------------------------------------------------------------" Cyan

    $ZipDir = Join-Path $SnapshotDir "$Ano\$Mes"
    $ZipFile = Join-Path $ZipDir "$($ProjectName)_$DataArquivo.zip"

    $Disco = Split-Path -Qualifier $SnapshotDir
    if (!(Test-Path $Disco)) {
        Write-Log "[AVISO] Disco $Disco nao acessivel. Snapshot ZIP ignorado." DarkYellow
        return
    }

    if ($DryRun) {
        Write-Log "[DRY-RUN] ZIP simulado: $ZipFile" DarkYellow
        return
    }

    if (!(Test-Path $ZipDir)) {
        New-Item -ItemType Directory -Path $ZipDir -Force | Out-Null
    }

    $TempDir = Join-Path $env:TEMP "$($ProjectName)_zip_$DataArquivo"
    if (Test-Path $TempDir) { Remove-Item $TempDir -Recurse -Force }
    New-Item -ItemType Directory -Path $TempDir -Force | Out-Null

    $XD = @()
    foreach ($dir in $ExcluidosDir) { $XD += @("/XD", $dir) }
    $XF = @()
    foreach ($file in $ExcluidosFiles) { $XF += @("/XF", $file) }

    robocopy $Origem $TempDir /MIR /R:2 /W:2 /NFL /NDL /NJH /NJS @XD @XF | Out-Null

    Compress-Archive -Path (Join-Path $TempDir "*") -DestinationPath $ZipFile -Force
    Remove-Item $TempDir -Recurse -Force

    Write-Log "[OK] Snapshot criado: $ZipFile" Green
}

function Backup-SupabaseDatabase {
    Write-Log "" White
    Write-Log "[BANCO] Exportando banco Supabase staging (supabase db dump --linked)" Yellow
    Write-Log "------------------------------------------------------------" Cyan

    if ($PularBanco) {
        Write-Log "[AVISO] Etapa de banco pulada (-PularBanco)." DarkYellow -LogType database
        return
    }

    if (!(Test-CommandExists "npx")) {
        Write-Log "[AVISO] npx nao encontrado no PATH. Etapa de banco ignorada." DarkYellow -LogType database
        return
    }

    $DbDir = Join-Path $SnapshotDir "$Ano\$Mes"
    $DbFile = Join-Path $DbDir "$($ProjectName)_db_$DataArquivo.sql"

    if ($DryRun) {
        Write-Log "[DRY-RUN] Dump do banco simulado: $DbFile" DarkYellow -LogType database
        return
    }

    if (!(Test-Path $DbDir)) {
        New-Item -ItemType Directory -Path $DbDir -Force | Out-Null
    }

    # --linked usa o projeto ja vinculado neste clone (staging,
    # ozvylnaipubrmaadikvk) - confirma antes: `npx supabase projects list`.
    # Dump padrao inclui schema + dados (nao so estrutura).
    Push-Location $ProjectRoot
    try {
        & npx supabase db dump --linked -f $DbFile 2>$null
        $code = $LASTEXITCODE
    } finally {
        Pop-Location
    }

    if ($code -ne 0 -or !(Test-Path $DbFile) -or (Get-Item $DbFile).Length -eq 0) {
        Write-Log "[ERRO] supabase db dump falhou (codigo $code) ou gerou arquivo vazio." Red -LogType database
        if (Test-Path $DbFile) { Remove-Item $DbFile -Force }
        throw "Falha ao exportar o banco Supabase staging"
    }

    $sizeKB = [math]::Round((Get-Item $DbFile).Length / 1KB, 1)
    Write-Log "[OK] Dump do banco criado: $DbFile ($sizeKB KB)" Green -LogType database

    # Copia o dump tambem para OneDrive e HD externo (pasta "database"),
    # separado do mirror de codigo. ATENCAO: a partir do M18/M19 este dump
    # contem dado real do cliente-piloto (Mania de Modas: CNPJ, IE, e-mail
    # do responsavel) - trate como sensivel mesmo sendo o banco "staging".
    foreach ($destino in @(
        @{ Path = (Join-Path $OneDriveDestino "database"); Nome = "OneDrive" },
        @{ Path = (Join-Path $ExternoDestino "database"); Nome = "HD Externo" }
    )) {
        $disco = Split-Path -Qualifier $destino.Path
        if (!(Test-Path $disco)) {
            Write-Log "[AVISO] Disco $disco nao acessivel. Copia do dump para $($destino.Nome) ignorada." DarkYellow -LogType database
            continue
        }
        if (!(Test-Path $destino.Path)) {
            New-Item -ItemType Directory -Path $destino.Path -Force | Out-Null
        }
        Copy-Item -Path $DbFile -Destination $destino.Path -Force
        Write-Log "[OK] Dump copiado para $($destino.Nome): $($destino.Path)" Green -LogType database
    }

    Write-Log "[LEMBRETE] O dump do banco NAO e commitado no Git - fica apenas em Snapshots/OneDrive/HD Externo." DarkCyan -LogType database
}

function Sync-GitHub {
    if (-not $SincronizarGit) {
        Write-Log "" White
        Write-Log "[GIT] Sincronizacao pulada (padrao) - use -SincronizarGit pra commitar/enviar." DarkYellow
        Write-Log "[GIT] Este projeto so commita em cima de portao validado (GOVERNANCA-EXECUCAO-AUTOMATICA.md); backup automatico nao deve commitar trabalho pela metade por engano." DarkYellow
        return
    }

    Write-Log "" White
    Write-Log "[GIT] Sincronizando branch $BranchPadrao com $GitRemote" Yellow
    Write-Log "------------------------------------------------------------" Cyan

    if (!(Test-Path $Origem)) {
        throw "Origem nao encontrada: $Origem"
    }

    Set-Location $Origem

    if (!(Test-CommandExists "git")) {
        throw "Git nao encontrado no PATH. Instale ou configure o Git."
    }

    if ($DryRun) {
        Write-Log "[DRY-RUN] Git sync simulado." DarkYellow
        return
    }

    $EAPAnterior = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $branchAtual = git rev-parse --abbrev-ref HEAD 2>$null
        if ($branchAtual -ne $BranchPadrao) {
            Write-Log "[ERRO] HEAD esta em '$branchAtual', nao em '$BranchPadrao'. Este script so sincroniza a branch $BranchPadrao - troca antes de rodar com -SincronizarGit." Red -LogType git
            throw "Branch atual diferente de $BranchPadrao"
        }

        $status = git status --porcelain 2>$null
        if ($status) {
            Write-Log "[GIT] Alteracoes detectadas. Preparando commit..." Cyan -LogType git
            git add -A 2>$null | Out-Null

            if ([string]::IsNullOrWhiteSpace($CommitMessage)) {
                $CommitMessage = "chore: backup automatico $DataHumana"
            }

            git commit -m $CommitMessage 2>$null | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Log "[OK] Commit criado: $CommitMessage" Green -LogType git
            } else {
                Write-Log "[AVISO] Commit nao criado. Verifique saida do Git." DarkYellow -LogType git
            }
        } else {
            Write-Log "[GIT] Sem alteracoes pendentes." DarkYellow -LogType git
        }

        Write-Log "[GIT] Enviando para GitHub ($GitRemote, branch $BranchPadrao)..." Cyan -LogType git
        $PushOutput = git push origin $BranchPadrao 2>&1
        foreach ($linha in $PushOutput) { Write-Log "[GIT-DETALHE] $linha" DarkGray -LogType git }

        if ($LASTEXITCODE -eq 0) {
            $hash = git rev-parse --short HEAD 2>$null
            Write-Log "[OK] Push realizado com sucesso. HEAD: $hash" Green -LogType git
            Write-Log "[AUDITORIA] commit=$hash" DarkCyan
        } else {
            Write-Log "[ERRO] Push falhou. Verifique credenciais, token ou conexao." Red -LogType git
            throw "Falha no git push"
        }
    } finally {
        $ErrorActionPreference = $EAPAnterior
    }
}

function Validate-Environment {
    Write-Log "" White
    Write-Log "[VALIDACAO] Ambiente" Yellow
    Write-Log "------------------------------------------------------------" Cyan

    if (!(Test-Path $Origem)) {
        throw "Pasta principal nao encontrada: $Origem"
    }
    Write-Log "[OK] Origem encontrada: $Origem" Green

    if (!(Test-CommandExists "git")) {
        throw "Git nao encontrado."
    }
    Write-Log "[OK] Git encontrado." Green

    if (!(Test-CommandExists "robocopy")) {
        throw "Robocopy nao encontrado."
    }
    Write-Log "[OK] Robocopy encontrado." Green

    if (!(Test-CommandExists "npx")) {
        Write-Log "[AVISO] npx nao encontrado - etapa de banco sera pulada." DarkYellow
    }

    if (!(Test-Path $ConfigPath)) {
        Write-Log "[AVISO] config/paths.json nao encontrado - usando defaults (copie config/paths.json.example e ajuste os caminhos reais)." DarkYellow
    }
}

try {
    Write-Log "" White
    Write-Log "============================================================" Cyan
    Write-Log "  $ProjectDisplayName | BACKUP MANAGER v1 | $DataHumana | user:$Usuario" White
    Write-Log "============================================================" Cyan

    Validate-Environment
    Sync-Robocopy -Destino $OneDriveDestino -NomeDestino "OneDrive"
    Sync-Robocopy -Destino $ExternoDestino -NomeDestino "HD Externo"
    Create-ZipSnapshot
    Backup-SupabaseDatabase
    Sync-GitHub

    $Duration = (Get-Date) - $StartTime

    Write-Log "" White
    Write-Log "============================================================" Green
    Write-Log "  BACKUP CONCLUIDO COM SUCESSO | $DataHumana | duracao: $($Duration.ToString('mm\:ss'))" Green
    Write-Log "============================================================" Green

    exit 0
} catch {
    $Duration = (Get-Date) - $StartTime
    Write-Log "" White
    Write-Log "============================================================" Red
    Write-Log "  BACKUP FALHOU | $($_.Exception.Message) | duracao: $($Duration.ToString('mm\:ss'))" Red
    Write-Log "============================================================" Red
    exit 1
}
