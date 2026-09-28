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
    $sample = [Text.Encoding]::UTF8.GetBytes('synthetic-metadata-only')
    $hash = Get-Sha256Hex -Bytes $sample
    [Array]::Clear($sample, 0, $sample.Length)
    if ($hash -notmatch '^[a-f0-9]{64}$') { throw 'SELF_TEST_HASH_FAILED' }
    Write-Host 'M13_G8_INSPECTOR_SELF_TEST_OK'
    exit 0
}

Add-Type -AssemblyName System.Windows.Forms
$dialog = New-Object System.Windows.Forms.OpenFileDialog
$dialog.Title = 'Select the pilot A1 certificate - local inspection only'
$dialog.Filter = 'PKCS#12 certificate (*.pfx;*.p12)|*.pfx;*.p12'
$dialog.CheckFileExists = $true
$dialog.Multiselect = $false

if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
    Write-Host 'M13_G8_CANCELLED'
    exit 2
}

$secret = Read-Host 'Enter the A1 password (masked, never stored)' -AsSecureString
$material = $null
$certificates = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2Collection
$chain = New-Object System.Security.Cryptography.X509Certificates.X509Chain

try {
    $material = [System.IO.File]::ReadAllBytes($dialog.FileName)
    $flags = [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::EphemeralKeySet
    $certificates.Import($material, $secret, $flags)
    if ($certificates.Count -lt 1) { throw 'CERTIFICATE_NOT_FOUND' }

    $leaf = $certificates | Where-Object { $_.HasPrivateKey } | Select-Object -First 1
    if ($null -eq $leaf) { throw 'PRIVATE_KEY_PAIR_NOT_FOUND' }

    $chain.ChainPolicy.RevocationMode = [System.Security.Cryptography.X509Certificates.X509RevocationMode]::NoCheck
    $chain.ChainPolicy.VerificationFlags = [System.Security.Cryptography.X509Certificates.X509VerificationFlags]::NoFlag
    $chainValid = $chain.Build($leaf)
    $subjectBytes = [Text.Encoding]::UTF8.GetBytes($leaf.Subject)
    try { $subjectHash = Get-Sha256Hex -Bytes $subjectBytes }
    finally { [Array]::Clear($subjectBytes, 0, $subjectBytes.Length) }

    $safeSubject = Protect-SubjectText -Text $leaf.Subject
    $thumbprint = $leaf.Thumbprint.Replace(' ', '').ToLowerInvariant()
    Write-Host ('M13_G8_LOCAL_INSPECTION_OK chainValid={0}' -f $chainValid)
    Write-Host ('subject={0}' -f $safeSubject)
    Write-Host ('subjectHash={0}' -f $subjectHash)
    Write-Host ('thumbprint={0}' -f $thumbprint)
    Write-Host ('validFrom={0:o}' -f $leaf.NotBefore.ToUniversalTime())
    Write-Host ('validUntil={0:o}' -f $leaf.NotAfter.ToUniversalTime())
    Write-Host 'privateKeyExported=false signed=false transmitted=false persisted=false'
}
finally {
    if ($null -ne $material) { [Array]::Clear($material, 0, $material.Length) }
    if ($null -ne $secret) { $secret.Dispose() }
    foreach ($certificate in $certificates) { $certificate.Dispose() }
    $chain.Dispose()
    $dialog.Dispose()
    Remove-Variable secret, material -ErrorAction SilentlyContinue
}
