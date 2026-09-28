param([switch]$SelfTest)

$ErrorActionPreference = 'Stop'

function Get-Sha256Hex {
    param([byte[]]$Bytes)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace('-', '').ToLowerInvariant() }
    finally { $sha.Dispose() }
}

function Protect-SubjectText {
    param([string]$Text)
    return [regex]::Replace($Text, '\d{14}', '**************')
}

if ($SelfTest) {
    $masked = Protect-SubjectText -Text 'CN=PILOT:11111111111111'
    if ($masked -match '\d{14}') { throw 'SELF_TEST_MASK_FAILED' }
    Write-Host 'M13_G8_INSTALLED_INSPECTOR_SELF_TEST_OK'
    exit 0
}

Add-Type -AssemblyName System.Security
$store = New-Object System.Security.Cryptography.X509Certificates.X509Store(
    [System.Security.Cryptography.X509Certificates.StoreName]::My,
    [System.Security.Cryptography.X509Certificates.StoreLocation]::CurrentUser
)
$chain = New-Object System.Security.Cryptography.X509Certificates.X509Chain

try {
    $store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadOnly)
    $candidates = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2Collection
    $now = [DateTime]::UtcNow
    foreach ($certificate in $store.Certificates) {
        $validNow = ($certificate.NotBefore.ToUniversalTime() -le $now) -and ($certificate.NotAfter.ToUniversalTime() -ge $now)
        if ($certificate.HasPrivateKey -and $validNow) { [void]$candidates.Add($certificate) }
    }
    if ($candidates.Count -lt 1) { throw 'NO_CERTIFICATE_WITH_PRIVATE_KEY_FOUND' }

    $selected = [System.Security.Cryptography.X509Certificates.X509Certificate2UI]::SelectFromCollection(
        $candidates,
        'Select installed A1 certificate',
        'Read-only metadata and chain inspection. No signing or export.',
        [System.Security.Cryptography.X509Certificates.X509SelectionFlag]::SingleSelection
    )
    if ($selected.Count -ne 1) { Write-Host 'M13_G8_CANCELLED'; exit 2 }
    $leaf = $selected[0]

    $chain.ChainPolicy.RevocationMode = [System.Security.Cryptography.X509Certificates.X509RevocationMode]::NoCheck
    $chain.ChainPolicy.VerificationFlags = [System.Security.Cryptography.X509Certificates.X509VerificationFlags]::NoFlag
    $chainValid = $chain.Build($leaf)
    $subjectBytes = [Text.Encoding]::UTF8.GetBytes($leaf.Subject)
    try { $subjectHash = Get-Sha256Hex -Bytes $subjectBytes }
    finally { [Array]::Clear($subjectBytes, 0, $subjectBytes.Length) }

    $validNow = ($leaf.NotBefore.ToUniversalTime() -le $now) -and ($leaf.NotAfter.ToUniversalTime() -ge $now)
    Write-Host ('M13_G8_INSTALLED_INSPECTION_OK chainValid={0} validNow={1}' -f $chainValid, $validNow)
    Write-Host ('subject={0}' -f (Protect-SubjectText -Text $leaf.Subject))
    Write-Host ('subjectHash={0}' -f $subjectHash)
    Write-Host ('thumbprint={0}' -f $leaf.Thumbprint.Replace(' ', '').ToLowerInvariant())
    Write-Host ('validFrom={0:o}' -f $leaf.NotBefore.ToUniversalTime())
    Write-Host ('validUntil={0:o}' -f $leaf.NotAfter.ToUniversalTime())
    foreach ($status in $chain.ChainStatus) { Write-Host ('chainStatus={0}' -f $status.Status) }
    Write-Host 'storeReadOnly=true privateKeyExported=false signed=false transmitted=false persisted=false'
}
finally {
    $chain.Dispose()
    $store.Close()
}
