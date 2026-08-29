param([switch]$SelfTest)

$ErrorActionPreference = 'Stop'

function New-SyntheticXml {
    $document = New-Object System.Xml.XmlDocument
    $document.PreserveWhitespace = $true
    $document.LoadXml('<SyntheticFiscalDocument Id="M13G9-SYNTHETIC-001"><Environment>homologation</Environment><FiscalValue>false</FiscalValue><Identity>synthetic-only</Identity><Amount>0.00</Amount></SyntheticFiscalDocument>')
    return $document
}

if ($SelfTest) {
    Add-Type -AssemblyName System.Security
    $xml = New-SyntheticXml
    if ($xml.OuterXml -match '\d{14}|CNPJ|CPF') { throw 'SELF_TEST_REAL_IDENTITY_FOUND' }
    if ($xml.OuterXml -notmatch 'FiscalValue>false') { throw 'SELF_TEST_FISCAL_VALUE_FAILED' }
    Write-Host 'M13_G9_SIGNER_SELF_TEST_OK'
    exit 0
}

Add-Type -AssemblyName System.Security
$store = New-Object System.Security.Cryptography.X509Certificates.X509Store(
    [System.Security.Cryptography.X509Certificates.StoreName]::My,
    [System.Security.Cryptography.X509Certificates.StoreLocation]::CurrentUser
)
$chain = New-Object System.Security.Cryptography.X509Certificates.X509Chain
$privateKey = $null
$publicKey = $null

try {
    $store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadOnly)
    $now = [DateTime]::UtcNow
    $candidates = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2Collection
    foreach ($certificate in $store.Certificates) {
        $validNow = ($certificate.NotBefore.ToUniversalTime() -le $now) -and ($certificate.NotAfter.ToUniversalTime() -ge $now)
        if ($certificate.HasPrivateKey -and $validNow) { [void]$candidates.Add($certificate) }
    }
    if ($candidates.Count -lt 1) { throw 'NO_VALID_CERTIFICATE_WITH_PRIVATE_KEY_FOUND' }

    $selected = [System.Security.Cryptography.X509Certificates.X509Certificate2UI]::SelectFromCollection(
        $candidates,
        'Select A1 for local synthetic signature',
        'No real identity, file output, CSC, network call or fiscal transmission.',
        [System.Security.Cryptography.X509Certificates.X509SelectionFlag]::SingleSelection
    )
    if ($selected.Count -ne 1) { Write-Host 'M13_G9_CANCELLED'; exit 2 }
    $leaf = $selected[0]

    $chain.ChainPolicy.RevocationMode = [System.Security.Cryptography.X509Certificates.X509RevocationMode]::NoCheck
    $chain.ChainPolicy.VerificationFlags = [System.Security.Cryptography.X509Certificates.X509VerificationFlags]::NoFlag
    if (-not $chain.Build($leaf)) { throw 'CERTIFICATE_CHAIN_INVALID' }

    $document = New-SyntheticXml
    $privateKey = [System.Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($leaf)
    $publicKey = [System.Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPublicKey($leaf)
    if ($null -eq $privateKey -or $null -eq $publicKey) { throw 'RSA_KEY_NOT_AVAILABLE' }

    $signedXml = New-Object System.Security.Cryptography.Xml.SignedXml($document)
    $signedXml.SigningKey = $privateKey
    $signedXml.SignedInfo.SignatureMethod = [System.Security.Cryptography.Xml.SignedXml]::XmlDsigRSASHA256Url
    $reference = New-Object System.Security.Cryptography.Xml.Reference
    $reference.Uri = '#M13G9-SYNTHETIC-001'
    $reference.DigestMethod = [System.Security.Cryptography.Xml.SignedXml]::XmlDsigSHA256Url
    $reference.AddTransform((New-Object System.Security.Cryptography.Xml.XmlDsigEnvelopedSignatureTransform))
    $reference.AddTransform((New-Object System.Security.Cryptography.Xml.XmlDsigC14NTransform))
    $signedXml.AddReference($reference)
    $signedXml.ComputeSignature()
    $document.DocumentElement.AppendChild($document.ImportNode($signedXml.GetXml(), $true)) | Out-Null

    $verifier = New-Object System.Security.Cryptography.Xml.SignedXml($document)
    $signatureNode = $document.GetElementsByTagName('Signature', [System.Security.Cryptography.Xml.SignedXml]::XmlDsigNamespaceUrl)[0]
    $verifier.LoadXml($signatureNode)
    $signatureValid = $verifier.CheckSignature($publicKey)
    $identityFree = $document.OuterXml -notmatch '\d{14}|CNPJ|CPF'
    $fiscalValue = $false

    Write-Host ('M13_G9_LOCAL_SIGNATURE_OK signatureValid={0} chainValid=True identityFree={1} fiscalValue={2}' -f $signatureValid, $identityFree, $fiscalValue)
    Write-Host 'privateKeyExported=false xmlPersisted=false cscUsed=false transmitted=false productionAccessed=false'
}
finally {
    if ($null -ne $privateKey) { $privateKey.Dispose() }
    if ($null -ne $publicKey) { $publicKey.Dispose() }
    $chain.Dispose()
    $store.Close()
    Remove-Variable document, signedXml, verifier, signatureNode -ErrorAction SilentlyContinue
}
