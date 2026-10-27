param(
    [ValidateSet('fenix847mm')]
    [string]$Device = 'fenix847mm',
    [string]$SdkPath = '',
    [string]$JavaPath = '',
    [string]$DeveloperKeyPath = '',
    [switch]$Test,
    [ValidateSet('Dev', 'Beta')]
    [string]$Variant = 'Dev',
    [switch]$Package
)
$ErrorActionPreference = 'Stop'
if ($Test -and $Package) { throw 'Un paquete Store no puede contener pruebas.' }
if ($Package -and $Variant -ne 'Beta') { throw 'La distribución Store de este bloque está limitada a la beta privada.' }
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
    if ($Variant -eq 'Beta') { throw 'La beta debe usar la clave de desarrollo existente; no generar otra silenciosamente.' }
    New-Item -ItemType Directory -Force -Path (Split-Path $DeveloperKeyPath -Parent) | Out-Null
    # Clave local de firma para sideload Dev, nunca credencial de cuenta o de servidor.
    $rsa = [System.Security.Cryptography.RSA]::Create(4096)
    try { [System.IO.File]::WriteAllBytes($DeveloperKeyPath, $rsa.ExportPkcs8PrivateKey()) }
    finally { $rsa.Dispose() }
}
$outputDir = Join-Path $PSScriptRoot 'bin'
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
$suffix = if ($Test) { '-tests' } else { '' }
$ciqVariantName = $Variant.ToLowerInvariant()
$outputFile = if ($Package) { Join-Path $outputDir "entrenaop-$ciqVariantName.iq" }
    else { Join-Path $outputDir "entrenaop-$ciqVariantName-$Device$suffix.prg" }
$jungle = if ($Variant -eq 'Beta') {
    if ($Test) { 'tests-beta.jungle' } else { 'beta.jungle' }
} else { if ($Test) { 'tests.jungle' } else { 'monkey.jungle' } }
$debugOriginal = Join-Path $SdkPath 'bin/api.debug.xml'
$debugImport = Join-Path $repo '.dart_tool/ciq-dev/api.local.debug.xml'
if (Test-Path -LiteralPath $debugOriginal) {
    # El SDK contiene rutas internas T:\ del equipo de Garmin. Si esa letra es
    # una unidad remota local, Java intenta resolver miles de fuentes ajenas.
    # Reubicar solo esas referencias de depuración en una copia, sin tocar el SDK.
    $debugSources = Join-Path $repo '.dart_tool/ciq-dev/sdk-source'
    New-Item -ItemType Directory -Force -Path $debugSources | Out-Null
    $debugText = [System.IO.File]::ReadAllText($debugOriginal).Replace('filename="T:\', 'filename="' + ($debugSources.Replace('\', '/') + '/'))
    [System.IO.File]::WriteAllText($debugImport, $debugText, [System.Text.UTF8Encoding]::new($false))
}
$compilerArgs = @('-Xms1g', '-Dfile.encoding=UTF-8', '-cp', $compiler, 'com.garmin.monkeybrains.Monkeybrains',
    '-f', (Join-Path $PSScriptRoot $jungle), '-y', $DeveloperKeyPath, '-o', $outputFile, '-l', '3', '-w')
if ($Package) { $compilerArgs += @('-e', '-r') } else { $compilerArgs += @('-d', $Device) }
if ($Test) { $compilerArgs += '-t' }
if (Test-Path -LiteralPath $debugImport) { $compilerArgs += @('-i', $debugImport) }
& $JavaPath @compilerArgs
if ($LASTEXITCODE -ne 0) { throw "La compilación Connect IQ ha fallado ($LASTEXITCODE)." }
if ($Package) {
    & $JavaPath -cp $compiler (Join-Path $PSScriptRoot 'VerifyPackage.java') $outputFile $DeveloperKeyPath
    if ($LASTEXITCODE -ne 0) { throw 'La verificación de firma del paquete IQ ha fallado.' }
}
Get-FileHash -LiteralPath $outputFile -Algorithm SHA256
