# ============================================================
# M18 - correcao pontual: e-mail do dono(a) da Mania de Modas foi
# digitado errado na coleta original (M18-G20/G21) - o convite foi
# confirmado (02/09), mas pela pessoa/caixa errada, nunca usada pra
# entrar de verdade. Este script:
#   1. Le o e-mail correto do cofre protegido local (mesmo formato do
#      m18-pilot-protected.json - roda Collect-PilotProvisioningProtected.ps1
#      de novo primeiro, com o e-mail certo, se ainda nao fez).
#   2. Confirma que o e-mail novo ainda nao existe no Auth (evita colisao).
#   3. Convida o e-mail correto (POST /auth/v1/invite).
#   4. Cria a membership + papel 'owner' pra esse novo usuario no tenant
#      da Mania de Modas, gravando direto via PostgREST com service_role
#      (sempre ignora RLS - sem precisar de RPC nova so pra isto).
#   5. Tenta remover o usuario antigo (e-mail errado); se
#      erp_identity_provisioning_steps tiver historico dele (referencia
#      sem cascata, de proposito - e auditoria real), a remocao e
#      recusada pela API e o script cai pro fallback seguro: so revoga a
#      membership antiga, sem apagar nada. Nos dois casos, o tenant fica
#      com exatamente uma membership 'owner' viva no final.
#
# Uso:  .\scripts\Fix-PilotOwnerEmail.ps1 -Apply
#       .\scripts\Fix-PilotOwnerEmail.ps1 -PreflightOnly
# ============================================================
param(
    [switch]$Apply,
    [switch]$PreflightOnly,
    [string]$ProjectRef = 'ozvylnaipubrmaadikvk'
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Security

$TenantId = '7f2f05c7-94a0-42dc-bcfc-7b3105c391e3'
$TenantSlug = 'maniademodas'
$OwnerRoleId = '1fd892ba-ffac-46b6-84d8-b009ce1596d2'
$OldWrongUserId = '61b57707-2292-49ff-8ca6-f43ccec087ed'

function Reveal-Cipher([string]$Cipher) {
    $protected = [Convert]::FromBase64String($Cipher)
    try {
        $bytes = [Security.Cryptography.ProtectedData]::Unprotect(
            $protected, $null, [Security.Cryptography.DataProtectionScope]::CurrentUser
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
        if ($users | Where-Object { $_.email -ieq $Email }) { throw 'FIX_EMAIL_ALREADY_EXISTS' }
        $page++
    } while ($users.Count -eq 1000)
}

if (-not $Apply -and -not $PreflightOnly) { throw 'FIX_APPLY_FLAG_REQUIRED' }
if ($Apply -and $PreflightOnly) { throw 'FIX_MODE_CONFLICT' }
if ($ProjectRef -ne 'ozvylnaipubrmaadikvk') { throw 'FIX_STAGING_ONLY' }

$vaultPath = Join-Path $env:LOCALAPPDATA 'ConnectionCyber\staging\m18-pilot-protected.json'
if (-not (Test-Path -LiteralPath $vaultPath)) { throw 'FIX_PROTECTED_VAULT_MISSING' }
$vault = Get-Content -LiteralPath $vaultPath -Raw -Encoding utf8 | ConvertFrom-Json
if ($vault.schemaVersion -ne 1 -or $vault.environment -ne 'staging') { throw 'FIX_PROTECTED_VAULT_INVALID' }

$ownerEmail = Reveal-Cipher $vault.ownerEmail
$serviceKey = $null
$newAuthUserId = $null
$newUserCreated = $false
$stage = 'validate_protected_email'

try {
    if ($ownerEmail -notmatch '^[^\s@]+@[^\s@]+\.[^\s@]+$') { throw 'FIX_INVALID_OWNER_EMAIL' }

    $stage = 'resolve_admin_key'
    $rawKeys = npx supabase projects api-keys --project-ref $ProjectRef --output json 2>$null
    if ($LASTEXITCODE -ne 0) { throw 'FIX_ADMIN_KEY_QUERY_FAILED' }
    $keyEntry = @($rawKeys | ConvertFrom-Json | Where-Object { $_.name -eq 'service_role' })[0]
    if ($null -eq $keyEntry -or [string]::IsNullOrWhiteSpace($keyEntry.api_key)) { throw 'FIX_ADMIN_KEY_MISSING' }
    $serviceKey = $keyEntry.api_key
    $baseUrl = "https://$ProjectRef.supabase.co"
    $headers = @{ apikey = $serviceKey; Authorization = "Bearer $serviceKey" }

    $stage = 'preflight_auth_email'
    Assert-AuthEmailAbsent $baseUrl $headers $ownerEmail
    if ($PreflightOnly) {
        Write-Output 'FIX_PREFLIGHT_OK emailAbsent=true secretsLogged=false'
        return
    }

    $stage = 'create_auth_invitation'
    $invite = Invoke-JsonPost "$baseUrl/auth/v1/invite" $headers @{ email = $ownerEmail; data = @{ pilot = $true; tenant_slug = $TenantSlug; require_mfa = $true } }
    $newAuthUserId = [string]$invite.id
    if ($newAuthUserId -notmatch '^[0-9a-f-]{36}$') { throw 'FIX_AUTH_RESPONSE_INVALID' }
    $newUserCreated = $true

    # service_role sempre ignora RLS - grava direto via PostgREST, sem
    # precisar de RPC nova so pra esta correcao pontual.
    $stage = 'create_new_membership'
    $restHeaders = $headers + @{ 'Content-Type' = 'application/json'; Prefer = 'return=representation' }
    $membershipBody = @{ tenant_id = $TenantId; user_id = $newAuthUserId; status = 'invited'; is_default = $true } | ConvertTo-Json -Compress
    $membershipResp = Invoke-WebRequest -UseBasicParsing -Method Post -Uri "$baseUrl/rest/v1/erp_tenant_memberships" -Headers $restHeaders -Body $membershipBody
    $newMembership = ($membershipResp.Content | ConvertFrom-Json)[0]
    $newMembershipId = [string]$newMembership.id
    if ($newMembershipId -notmatch '^[0-9a-f-]{36}$') { throw 'FIX_MEMBERSHIP_RESPONSE_INVALID' }

    $stage = 'create_new_membership_role'
    $roleBody = @{ tenant_id = $TenantId; membership_id = $newMembershipId; role_id = $OwnerRoleId } | ConvertTo-Json -Compress
    Invoke-WebRequest -UseBasicParsing -Method Post -Uri "$baseUrl/rest/v1/erp_membership_roles" -Headers $restHeaders -Body $roleBody | Out-Null

    $stage = 'retire_old_wrong_email_membership'
    # Tentativa 1: apagar o usuario antigo direto. Cascata cobre
    # erp_tenant_memberships/erp_membership_roles (on delete cascade), MAS
    # erp_identity_provisioning_steps referencia o user_id SEM cascata de
    # proposito (e o historico real de auditoria do provisionamento
    # original) - a Auth API recusa o delete com FK violation (23503) se
    # esse usuario tiver passos registrados. Comportamento correto do
    # schema, nao um bug: preservar auditoria vale mais que limpar uma
    # linha. Fallback: so revoga a membership antiga (nao apaga nada),
    # deixando exatamente uma membership 'owner' viva pro tenant.
    $oldUserRemoved = $false
    try {
        Invoke-WebRequest -UseBasicParsing -Method Delete -Uri "$baseUrl/auth/v1/admin/users/$OldWrongUserId" -Headers $headers | Out-Null
        $oldUserRemoved = $true
    } catch {
        $revokeHeaders = $headers + @{ 'Content-Type' = 'application/json' }
        Invoke-WebRequest -UseBasicParsing -Method Patch `
            -Uri "$baseUrl/rest/v1/erp_tenant_memberships?tenant_id=eq.$TenantId&user_id=eq.$OldWrongUserId" `
            -Headers $revokeHeaders -Body '{"status":"revoked"}' | Out-Null
        Write-Output 'FIX_OLD_USER_KEPT_AUDIT_TRAIL_MEMBERSHIP_REVOKED'
    }

    Write-Output "FIX_OK newAuthUser=1 oldUserRemoved=$([int]$oldUserRemoved) membershipId=$newMembershipId invitation=sent secretsLogged=false"
}
catch {
    $safeCode = $_.Exception.Message
    if ($newUserCreated -and $null -ne $serviceKey -and $newAuthUserId -match '^[0-9a-f-]{36}$') {
        try {
            $headers = @{ apikey = $serviceKey; Authorization = "Bearer $serviceKey" }
            Invoke-WebRequest -UseBasicParsing -Method Delete -Uri "https://$ProjectRef.supabase.co/auth/v1/admin/users/$newAuthUserId" -Headers $headers | Out-Null
        }
        catch {}
    }
    Write-Output "FIX_FAILED_STAGE=$stage"
    if ($safeCode -eq 'FIX_EMAIL_ALREADY_EXISTS') { Write-Output 'FIX_EMAIL_ALREADY_EXISTS' }
    throw 'FIX_FAILED_FAIL_CLOSED'
}
finally {
    $ownerEmail = $null
    $serviceKey = $null
    $rawKeys = $null
}
