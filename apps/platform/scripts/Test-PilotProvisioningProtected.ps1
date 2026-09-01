$ErrorActionPreference = 'Stop'

function Reveal-Cipher([string]$Cipher) {
    $secure = ConvertTo-SecureString $Cipher
    $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer) }
}

$vaultPath = Join-Path $env:LOCALAPPDATA 'ConnectionCyber\staging\m18-pilot-protected.json'
if (-not (Test-Path -LiteralPath $vaultPath)) { throw 'M18_G20_PROTECTED_VAULT_MISSING' }
$payload = Get-Content -LiteralPath $vaultPath -Raw -Encoding utf8 | ConvertFrom-Json
if ($payload.schemaVersion -ne 1 -or $payload.environment -ne 'staging') { throw 'M18_G20_PROTECTED_VAULT_INVALID' }

$legalName = Reveal-Cipher $payload.legalName
$taxId = Reveal-Cipher $payload.taxId
$stateRegistration = Reveal-Cipher $payload.stateRegistration
$ownerEmail = Reveal-Cipher $payload.ownerEmail
try {
    if ($legalName -notmatch '^.{3,200}$') { throw 'M18_G20_INVALID_LEGAL_NAME' }
    if ($taxId -notmatch '^\d{14}$') { throw 'M18_G20_INVALID_CNPJ' }
    if ($stateRegistration -notmatch '^[A-Z0-9]{2,20}$') { throw 'M18_G20_INVALID_STATE_REGISTRATION' }
    if ($ownerEmail -notmatch '^[^\s@]+@[^\s@]+\.[^\s@]+$') { throw 'M18_G20_INVALID_OWNER_EMAIL' }
    Write-Output 'M18_G20_PROTECTED_CONFIG_OK fields=4 plaintextLogged=false gitPersisted=false'
}
finally {
    $legalName = $null
    $taxId = $null
    $stateRegistration = $null
    $ownerEmail = $null
}
