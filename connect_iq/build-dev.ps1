param(
    [ValidateSet('fenix847mm')]
    [string]$Device = 'fenix847mm',
    [string]$SdkPath = '',
    [string]$JavaPath = '',
    [string]$DeveloperKeyPath = '',
    [switch]$Test
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
if (!$SdkPath) { $SdkPath = Join-Path $repo '.dart_tool/ciq-sdk' }
if (!$JavaPath) {
    $androidJava = 'C:/Program Files/Android/Android Studio/jbr/bin/java.exe'
    $JavaPath = if (Test-Path -LiteralPath $androidJava) { $androidJava } else { (Get-Command java).Source }
}
$compiler = Join-Path $SdkPath 'bin/monkeybrains.jar'
if (!(Test-Path -LiteralPath $compiler)) { throw "No se encuentra el SDK Connect IQ en $SdkPath" }
if (!$DeveloperKeyPath) { $DeveloperKeyPath = Join-Path $repo '.dart_tool/ciq-dev/developer_key.der' }
if (!(Test-Path -LiteralPath $DeveloperKeyPath)) {
    New-Item -ItemType Directory -Force -Path (Split-Path $DeveloperKeyPath -Parent) | Out-Null
    # Clave local de firma para sideload Dev, nunca credencial de cuenta o de servidor.
    $rsa = [System.Security.Cryptography.RSA]::Create(4096)
    try { [System.IO.File]::WriteAllBytes($DeveloperKeyPath, $rsa.ExportPkcs8PrivateKey()) }
    finally { $rsa.Dispose() }
}
$outputDir = Join-Path $PSScriptRoot 'bin'
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
$suffix = if ($Test) { '-tests' } else { '' }
$outputFile = Join-Path $outputDir "entrenaop-dev-$Device$suffix.prg"
$jungle = if ($Test) { 'tests.jungle' } else { 'monkey.jungle' }
$compilerArgs = @('-Xms1g', '-Dfile.encoding=UTF-8', '-cp', $compiler, 'com.garmin.monkeybrains.Monkeybrains',
    '-f', (Join-Path $PSScriptRoot $jungle), '-d', $Device, '-y', $DeveloperKeyPath, '-o', $outputFile, '-l', '3', '-w')
if ($Test) { $compilerArgs += '-t' }
& $JavaPath @compilerArgs
if ($LASTEXITCODE -ne 0) { throw "La compilación Connect IQ ha fallado ($LASTEXITCODE)." }
Get-FileHash -LiteralPath $outputFile -Algorithm SHA256
