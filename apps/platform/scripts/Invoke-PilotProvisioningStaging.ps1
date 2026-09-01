param(
    [switch]$Apply,
    [switch]$PreflightOnly,
    [string]$ProjectRef = 'ozvylnaipubrmaadikvk'
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Security

function Reveal-Cipher([string]$Cipher) {
    $protected = [Convert]::FromBase64String($Cipher)
    try {
        $bytes = [Security.Cryptography.ProtectedData]::Unprotect(
            $protected,
            $null,
            [Security.Cryptography.DataProtectionScope]::CurrentUser
        )
        try { return [Text.Encoding]::UTF8.GetString($bytes) }
        finally { [Array]::Clear($bytes, 0, $bytes.Length) }
    }
    finally { [Array]::Clear($protected, 0, $protected.Length) }
}

function Invoke-JsonPost([string]$Uri, [hashtable]$Headers, [object]$Body) {
    $response = Invoke-WebRequest -UseBasicParsing -Method Post -Uri $Uri -Headers $Headers -ContentType 'application/json' -Body ($Body | ConvertTo-Json -Depth 8 -Compress)
    if ([string]::IsNullOrWhiteSpace($response.Content)) { return $null }
    return $response.Content | ConvertFrom-Json
}

function Assert-AuthEmailAbsent([string]$BaseUrl, [hashtable]$Headers, [string]$Email) {
    $page = 1
    do {
        $http = Invoke-WebRequest -UseBasicParsing -Method Get -Uri "$BaseUrl/auth/v1/admin/users?page=$page&per_page=1000" -Headers $Headers
        $response = $http.Content | ConvertFrom-Json
        $users = @($response.users)
        if ($users | Where-Object { $_.email -ieq $Email }) { throw 'M18_G21_AUTH_EMAIL_ALREADY_EXISTS' }
        $page++
    } while ($users.Count -eq 1000)
}

if (-not $Apply -and -not $PreflightOnly) { throw 'M18_G21_APPLY_FLAG_REQUIRED' }
if ($Apply -and $PreflightOnly) { throw 'M18_G21_MODE_CONFLICT' }
if ($ProjectRef -ne 'ozvylnaipubrmaadikvk') { throw 'M18_G21_STAGING_ONLY' }

$vaultPath = Join-Path $env:LOCALAPPDATA 'ConnectionCyber\staging\m18-pilot-protected.json'
if (-not (Test-Path -LiteralPath $vaultPath)) { throw 'M18_G21_PROTECTED_VAULT_MISSING' }
$vault = Get-Content -LiteralPath $vaultPath -Raw -Encoding utf8 | ConvertFrom-Json
if ($vault.schemaVersion -ne 1 -or $vault.environment -ne 'staging') { throw 'M18_G21_PROTECTED_VAULT_INVALID' }

$legalName = Reveal-Cipher $vault.legalName
$taxId = Reveal-Cipher $vault.taxId
$stateRegistration = Reveal-Cipher $vault.stateRegistration
$ownerEmail = Reveal-Cipher $vault.ownerEmail
$serviceKey = $null
$authUserId = $null
$authCreated = $false
$stage = 'validate_protected_values'

try {
    if ($legalName -notmatch '^.{3,200}$') { throw 'M18_G21_INVALID_LEGAL_NAME' }
    if ($taxId -notmatch '^\d{14}$') { throw 'M18_G21_INVALID_CNPJ' }
    if ($stateRegistration -notmatch '^[A-Z0-9]{2,20}$') { throw 'M18_G21_INVALID_STATE_REGISTRATION' }
    if ($ownerEmail -notmatch '^[^\s@]+@[^\s@]+\.[^\s@]+$') { throw 'M18_G21_INVALID_OWNER_EMAIL' }

    $stage = 'resolve_admin_key'
    $rawKeys = npx supabase projects api-keys --project-ref $ProjectRef --output json 2>$null
    if ($LASTEXITCODE -ne 0) { throw 'M18_G21_ADMIN_KEY_QUERY_FAILED' }
    $keyEntry = @($rawKeys | ConvertFrom-Json | Where-Object { $_.name -eq 'service_role' })[0]
    if ($null -eq $keyEntry -or [string]::IsNullOrWhiteSpace($keyEntry.api_key)) { throw 'M18_G21_ADMIN_KEY_MISSING' }
    $serviceKey = $keyEntry.api_key
    $baseUrl = "https://$ProjectRef.supabase.co"
    $headers = @{ apikey = $serviceKey; Authorization = "Bearer $serviceKey" }
    $stage = 'preflight_auth_email'
    Assert-AuthEmailAbsent $baseUrl $headers $ownerEmail
    if ($PreflightOnly) {
        Write-Output 'M18_G21_AUTH_PREFLIGHT_OK emailAbsent=true secretsLogged=false'
        return
    }

    $request = [ordered]@{
        idempotencyKey = 'pilot:staging:m18-g21:maniademodas-v1'
        slug = 'maniademodas'
        domain = 'maniademoda.connectioncyber.com.br'
        displayName = 'Mania de Modas'
        vertical = 'varejo-moda-calcados'
        legalName = $legalName
        tradeName = 'Mania de Moda'
        cnpj = $taxId
        stateRegistration = $stateRegistration
        establishmentCode = 'MATRIZ'
        ownerSubjectKey = 'maniademodas-owner'
        ownerEmailRef = 'protected:M18_PILOT_OWNER_EMAIL'
        capabilities = @('core.parties','core.catalog','inventory.stock','sales.pos','finance')
    }
    $stage = 'prepare_postgres'
    $prepared = Invoke-JsonPost "$baseUrl/rest/v1/rpc/erp_prepare_pilot_provisioning_v1" $headers @{ p_request = $request }
    if ($null -eq $prepared.runId -or $null -eq $prepared.tenantId) { throw 'M18_G21_PREPARE_RESPONSE_INVALID' }

    $stage = 'create_auth_invitation'
    $invite = Invoke-JsonPost "$baseUrl/auth/v1/invite" $headers @{ email = $ownerEmail; data = @{ pilot = $true; tenant_slug = 'maniademodas'; require_mfa = $true } }
    $authUserId = [string]$invite.id
    if ($authUserId -notmatch '^[0-9a-f-]{36}$') { throw 'M18_G21_AUTH_RESPONSE_INVALID' }
    $authCreated = $true

    $stage = 'record_auth_identity'
    $recorded = Invoke-JsonPost "$baseUrl/rest/v1/rpc/erp_record_pilot_auth_identity_v1" $headers @{ p_run_id = [string]$prepared.runId; p_auth_user_id = $authUserId }
    if ([string]$recorded.userId -ne $authUserId) { throw 'M18_G21_AUTH_RECORD_INVALID' }
    $stage = 'finalize_identity'
    $finalized = Invoke-JsonPost "$baseUrl/rest/v1/rpc/erp_finalize_pilot_identity_v1" $headers @{ p_run_id = [string]$prepared.runId; p_auth_user_id = $authUserId }
    if ([string]$finalized.userId -ne $authUserId -or $finalized.mfaRequired -ne $true) { throw 'M18_G21_FINALIZE_INVALID' }

    Write-Output 'M18_G21_PROVISIONING_OK tenant=1 authUser=1 membership=1 ownerRole=1 invitation=sent mfaRequired=true secretsLogged=false production=false'
}
catch {
    $safeCode = $_.Exception.Message
    if ($authCreated -and $null -ne $serviceKey -and $authUserId -match '^[0-9a-f-]{36}$') {
        try {
            $headers = @{ apikey = $serviceKey; Authorization = "Bearer $serviceKey" }
            Invoke-WebRequest -UseBasicParsing -Method Delete -Uri "https://$ProjectRef.supabase.co/auth/v1/admin/users/$authUserId" -Headers $headers | Out-Null
        }
        catch {}
    }
    Write-Output "M18_G21_FAILED_STAGE=$stage"
    if ($safeCode -eq 'M18_G21_AUTH_EMAIL_ALREADY_EXISTS') { Write-Output 'M18_G21_AUTH_EMAIL_ALREADY_EXISTS' }
    throw 'M18_G21_PROVISIONING_FAILED_FAIL_CLOSED'
}
finally {
    $legalName = $null
    $taxId = $null
    $stateRegistration = $null
    $ownerEmail = $null
    $serviceKey = $null
    $rawKeys = $null
}
