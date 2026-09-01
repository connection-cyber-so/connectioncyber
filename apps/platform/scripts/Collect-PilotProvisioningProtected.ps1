$ErrorActionPreference = 'Stop'

function Read-Protected([string]$Prompt) {
    return Read-Host $Prompt -AsSecureString
}

function Reveal-Protected([Security.SecureString]$Value) {
    $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Value)
    try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer) }
}

function Assert-Format([string]$Name, [string]$Value, [string]$Pattern) {
    if ($Value -notmatch $Pattern) { throw "M18_G20_INVALID_$Name" }
}

function Protect-Text([string]$Value) {
    $bytes = [Text.Encoding]::UTF8.GetBytes($Value)
    try {
        $protected = [Security.Cryptography.ProtectedData]::Protect(
            $bytes,
            $null,
            [Security.Cryptography.DataProtectionScope]::CurrentUser
        )
        return [Convert]::ToBase64String($protected)
    }
    finally {
        [Array]::Clear($bytes, 0, $bytes.Length)
    }
}

$vaultDirectory = Join-Path $env:LOCALAPPDATA 'ConnectionCyber\staging'
$vaultPath = Join-Path $vaultDirectory 'm18-pilot-protected.json'
$legalName = Read-Protected 'Razao social (masked)'
$taxId = Read-Protected 'CNPJ com 14 digitos (masked)'
$stateRegistration = Read-Protected 'Inscricao estadual, 2-20 letras/digitos (masked)'
$ownerEmail = Read-Protected 'E-mail do usuario-piloto (masked)'

try {
    $legalNameText = Reveal-Protected $legalName
    $taxIdText = Reveal-Protected $taxId
    $stateRegistrationText = (Reveal-Protected $stateRegistration).ToUpperInvariant()
    $ownerEmailText = (Reveal-Protected $ownerEmail).ToLowerInvariant()
    Assert-Format 'LEGAL_NAME' $legalNameText '^.{3,200}$'
    Assert-Format 'CNPJ' $taxIdText '^\d{14}$'
    Assert-Format 'STATE_REGISTRATION' $stateRegistrationText '^[A-Z0-9]{2,20}$'
    Assert-Format 'OWNER_EMAIL' $ownerEmailText '^[^\s@]+@[^\s@]+\.[^\s@]+$'

    New-Item -ItemType Directory -Path $vaultDirectory -Force | Out-Null
    $payload = [ordered]@{
        schemaVersion = 1
        environment = 'staging'
        legalName = Protect-Text $legalNameText
        taxId = Protect-Text $taxIdText
        stateRegistration = Protect-Text $stateRegistrationText
        ownerEmail = Protect-Text $ownerEmailText
    }
    $payload | ConvertTo-Json | Set-Content -LiteralPath $vaultPath -Encoding utf8
    Write-Output 'M18_G20_PROTECTED_COLLECTION_OK'
}
finally {
    $legalNameText = $null
    $taxIdText = $null
    $stateRegistrationText = $null
    $ownerEmailText = $null
}
