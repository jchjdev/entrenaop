param([string]$SdkPath = '', [string]$JavaPath = '', [ValidateSet('Dev', 'Beta')][string]$Variant = 'Dev')
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
if (!$SdkPath) { $SdkPath = Join-Path $repo '.dart_tool/ciq-sdk' }
if (!$JavaPath) {
    $androidJava = 'C:/Program Files/Android/Android Studio/jbr/bin/java.exe'
    $JavaPath = if (Test-Path -LiteralPath $androidJava) { $androidJava } else { (Get-Command java).Source }
}
& (Join-Path $PSScriptRoot 'build-dev.ps1') -Test -SdkPath $SdkPath -JavaPath $JavaPath -Variant $Variant
$ciqTestFile = 'bin/entrenaop-' + $Variant.ToLowerInvariant() + '-fenix847mm-tests.prg'
$testRunnerArgs = @('-classpath', (Join-Path $SdkPath 'bin/monkeybrains.jar'),
    'com.garmin.monkeybrains.monkeydodeux.MonkeyDoDeux',
    '-f', (Join-Path $PSScriptRoot $ciqTestFile),
    '-d', 'fenix847mm', '-s', (Join-Path $SdkPath 'bin/shell.exe'), '-t')
$testOutput = & $JavaPath @testRunnerArgs 2>&1
$runnerCode = $LASTEXITCODE
$report = $testOutput -join "`n"
Write-Output $report
# MonkeyDoDeux en Windows devuelve 1 incluso con PASSED. Solo aceptar ese
# caso si hay pruebas ejecutadas y un resumen explícito sin fallos ni errores.
if ($runnerCode -notin @(0, 1) -or $report -notmatch '(?m)^Ran [1-9][0-9]* tests?\s*$' -or
    $report -notmatch '(?m)^PASSED \(passed=[1-9][0-9]*, failed=0, errors=0\)\s*$' -or
    $report -match '(?m)^(FAIL|FAILED|ERROR)\b') {
    throw "La prueba Connect IQ no ha terminado correctamente (runner $runnerCode)."
}
exit 0
