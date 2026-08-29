param([switch]$SelfTest)

$ErrorActionPreference = 'Stop'
$schemaPath = Join-Path $PSScriptRoot '..\schemas\nfe\010e_v1.02\xsd\PL_010e_v1.02\NFe\nfe_v4.00.xsd'

function New-SyntheticNFeXml {
    $xml = @'
<NFe xmlns="http://www.portalfiscal.inf.br/nfe"><infNFe Id="NFe35260800000000000000550010000000011000000010" versao="4.00"><ide><cUF>35</cUF><cNF>00000001</cNF><natOp>OPERACAO SINTETICA SEM VALOR FISCAL</natOp><mod>55</mod><serie>1</serie><nNF>1</nNF><dhEmi>2026-08-28T12:00:00-03:00</dhEmi><tpNF>1</tpNF><idDest>1</idDest><cMunFG>3550308</cMunFG><tpImp>1</tpImp><tpEmis>1</tpEmis><cDV>0</cDV><tpAmb>2</tpAmb><finNFe>1</finNFe><indFinal>1</indFinal><indPres>1</indPres><procEmi>0</procEmi><verProc>CC-M13G10</verProc></ide><emit><CNPJ>00000000000000</CNPJ><xNome>EMITENTE SINTETICO - SEM VALOR FISCAL</xNome><enderEmit><xLgr>RUA SINTETICA</xLgr><nro>0</nro><xBairro>BAIRRO SINTETICO</xBairro><cMun>3550308</cMun><xMun>SAO PAULO</xMun><UF>SP</UF><CEP>00000000</CEP><cPais>1058</cPais><xPais>BRASIL</xPais></enderEmit><IE>000000000000</IE><CRT>1</CRT></emit><det nItem="1"><prod><cProd>SYNTHETIC-001</cProd><cEAN>SEM GTIN</cEAN><xProd>ITEM SINTETICO SEM VALOR FISCAL</xProd><NCM>00000000</NCM><CFOP>5102</CFOP><uCom>UN</uCom><qCom>1.0000</qCom><vUnCom>1.0000000000</vUnCom><vProd>1.00</vProd><cEANTrib>SEM GTIN</cEANTrib><uTrib>UN</uTrib><qTrib>1.0000</qTrib><vUnTrib>1.0000000000</vUnTrib><indTot>1</indTot></prod><imposto><ICMS><ICMSSN102><orig>0</orig><CSOSN>102</CSOSN></ICMSSN102></ICMS><PIS><PISNT><CST>07</CST></PISNT></PIS><COFINS><COFINSNT><CST>07</CST></COFINSNT></COFINS></imposto></det><total><ICMSTot><vBC>0.00</vBC><vICMS>0.00</vICMS><vICMSDeson>0.00</vICMSDeson><vFCP>0.00</vFCP><vBCST>0.00</vBCST><vST>0.00</vST><vFCPST>0.00</vFCPST><vFCPSTRet>0.00</vFCPSTRet><vProd>1.00</vProd><vFrete>0.00</vFrete><vSeg>0.00</vSeg><vDesc>0.00</vDesc><vII>0.00</vII><vIPI>0.00</vIPI><vIPIDevol>0.00</vIPIDevol><vPIS>0.00</vPIS><vCOFINS>0.00</vCOFINS><vOutro>0.00</vOutro><vNF>1.00</vNF></ICMSTot></total><transp><modFrete>9</modFrete></transp><pag><detPag><tPag>90</tPag><vPag>0.00</vPag></detPag></pag><infAdic><infCpl>DOCUMENTO SINTETICO SEM VALOR FISCAL - NAO TRANSMITIR</infCpl></infAdic></infNFe></NFe>
'@
    $document = New-Object System.Xml.XmlDocument
    $document.PreserveWhitespace = $true
    $document.LoadXml($xml)
    return $document
}

function Test-XmlSchema {
    param([System.Xml.XmlDocument]$Document)
    $errors = New-Object System.Collections.Generic.List[string]
    $settings = New-Object System.Xml.XmlReaderSettings
    $settings.ValidationType = [System.Xml.ValidationType]::Schema
    $settings.Schemas.Add('http://www.portalfiscal.inf.br/nfe', $schemaPath) | Out-Null
    $settings.add_ValidationEventHandler({ param($sender, $eventArgs) $errors.Add($eventArgs.Message) })
    $reader = [System.Xml.XmlReader]::Create((New-Object System.IO.StringReader($Document.OuterXml)), $settings)
    try { while ($reader.Read()) { } } finally { $reader.Dispose() }
    if ($errors.Count -gt 0) { throw ('NFE_SCHEMA_INVALID: ' + ($errors -join ' | ')) }
    return $true
}

if ($SelfTest) {
    $document = New-SyntheticNFeXml
    if ($document.OuterXml -notmatch '<tpAmb>2</tpAmb>') { throw 'SELF_TEST_ENVIRONMENT_FAILED' }
    if ($document.OuterXml -notmatch '<CNPJ>00000000000000</CNPJ>') { throw 'SELF_TEST_SYNTHETIC_IDENTITY_FAILED' }
    Write-Host 'M13_G10_CANONICAL_NFE_SELF_TEST_OK'
    exit 0
}

Add-Type -AssemblyName System.Security
$store = New-Object System.Security.Cryptography.X509Certificates.X509Store([System.Security.Cryptography.X509Certificates.StoreName]::My, [System.Security.Cryptography.X509Certificates.StoreLocation]::CurrentUser)
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
    $selected = [System.Security.Cryptography.X509Certificates.X509Certificate2UI]::SelectFromCollection($candidates, 'Select A1 for canonical NF-e local validation', 'Local schema validation and in-memory signature only. No transmission.', [System.Security.Cryptography.X509Certificates.X509SelectionFlag]::SingleSelection)
    if ($selected.Count -ne 1) { Write-Host 'M13_G10_CANCELLED'; exit 2 }
    $leaf = $selected[0]
    $chain.ChainPolicy.RevocationMode = [System.Security.Cryptography.X509Certificates.X509RevocationMode]::NoCheck
    if (-not $chain.Build($leaf)) { throw 'CERTIFICATE_CHAIN_INVALID' }

    $document = New-SyntheticNFeXml
    $privateKey = [System.Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($leaf)
    $publicKey = [System.Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPublicKey($leaf)
    $signedXml = New-Object System.Security.Cryptography.Xml.SignedXml($document)
    $signedXml.SigningKey = $privateKey
    $signedXml.SignedInfo.SignatureMethod = [System.Security.Cryptography.Xml.SignedXml]::XmlDsigRSASHA1Url
    $reference = New-Object System.Security.Cryptography.Xml.Reference
    $reference.Uri = '#NFe35260800000000000000550010000000011000000010'
    $reference.DigestMethod = [System.Security.Cryptography.Xml.SignedXml]::XmlDsigSHA1Url
    $reference.AddTransform((New-Object System.Security.Cryptography.Xml.XmlDsigEnvelopedSignatureTransform))
    $reference.AddTransform((New-Object System.Security.Cryptography.Xml.XmlDsigC14NTransform))
    $signedXml.AddReference($reference)
    $keyInfo = New-Object System.Security.Cryptography.Xml.KeyInfo
    $x509Data = New-Object System.Security.Cryptography.Xml.KeyInfoX509Data($leaf)
    $keyInfo.AddClause($x509Data)
    $signedXml.KeyInfo = $keyInfo
    $signedXml.ComputeSignature()
    $document.DocumentElement.AppendChild($document.ImportNode($signedXml.GetXml(), $true)) | Out-Null
    $schemaValid = Test-XmlSchema -Document $document
    $verifier = New-Object System.Security.Cryptography.Xml.SignedXml($document)
    $signatureNode = $document.GetElementsByTagName('Signature', [System.Security.Cryptography.Xml.SignedXml]::XmlDsigNamespaceUrl)[0]
    $verifier.LoadXml($signatureNode)
    $signatureValid = $verifier.CheckSignature($publicKey)
    $pilotIdentityAbsent = $document.OuterXml -match '<CNPJ>00000000000000</CNPJ>'
    Write-Host ('M13_G10_CANONICAL_NFE_OK schemaValid={0} signatureValid={1} chainValid=True pilotIdentityAbsent={2}' -f $schemaValid, $signatureValid, $pilotIdentityAbsent)
    Write-Host 'model=55 environment=homologation syntheticIdentity=true fiscalValue=false xmlPersisted=false cscUsed=false transmitted=false productionAccessed=false'
}
finally {
    if ($null -ne $privateKey) { $privateKey.Dispose() }
    if ($null -ne $publicKey) { $publicKey.Dispose() }
    $chain.Dispose()
    $store.Close()
    Remove-Variable document, signedXml, verifier, signatureNode -ErrorAction SilentlyContinue
}
