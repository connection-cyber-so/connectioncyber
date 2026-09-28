$ErrorActionPreference = 'Stop'

function Read-ProtectedValue([string]$Prompt) {
    $secure = Read-Host $Prompt -AsSecureString
    $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer) }
}

$names = @('CREDENTIALED','A1_MATCH','STATE','STATE_CODE','MUNICIPALITY_CODE','STATE_REGISTRATION','CRT','SERIES','NUMBER','NCM','CFOP','CSOSN','OPERATION_APPROVED')
try {
    $env:M13_G18_CREDENTIALED = Read-ProtectedValue 'Credenciado em homologacao? Digite true ou false (masked)'
    $env:M13_G18_A1_MATCH = Read-ProtectedValue 'A1 corresponde ao emitente? Digite true ou false (masked)'
    $env:M13_G18_STATE = (Read-ProtectedValue 'UF com 2 letras (masked)').ToUpperInvariant()
    $env:M13_G18_STATE_CODE = Read-ProtectedValue 'Codigo IBGE da UF com 2 digitos (masked)'
    $env:M13_G18_MUNICIPALITY_CODE = Read-ProtectedValue 'Codigo IBGE do municipio com 7 digitos (masked)'
    $env:M13_G18_STATE_REGISTRATION = Read-ProtectedValue 'Inscricao estadual somente digitos (masked)'
    $env:M13_G18_CRT = Read-ProtectedValue 'CRT 1, 2, 3 ou 4 (masked)'
    $env:M13_G18_SERIES = Read-ProtectedValue 'Serie de homologacao 0 a 999 (masked)'
    $env:M13_G18_NUMBER = Read-ProtectedValue 'Proximo numero de homologacao 1 a 999999999 (masked)'
    $env:M13_G18_NCM = Read-ProtectedValue 'NCM com 8 digitos (masked)'
    $env:M13_G18_CFOP = Read-ProtectedValue 'CFOP de saida com 4 digitos (masked)'
    $env:M13_G18_CSOSN = Read-ProtectedValue 'CSOSN com 3 digitos (masked)'
    $env:M13_G18_OPERATION_APPROVED = Read-ProtectedValue 'Operacao fiscal aprovada? Digite true ou false (masked)'
    & node (Join-Path $PSScriptRoot 'validate-pilot-config-env.mjs')
    exit $LASTEXITCODE
}
finally {
    foreach ($name in $names) { Remove-Item -LiteralPath "Env:M13_G18_$name" -ErrorAction SilentlyContinue }
}
