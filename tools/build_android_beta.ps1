param(
    [string]$SigningPropertiesPath = '',
    [string]$OutputDirectory = ''
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'android_beta_verification.ps1')
if (!$SigningPropertiesPath) {
    $SigningPropertiesPath = Join-Path $env:USERPROFILE '.android/entrenaop-beta-signing/key.properties'
}
if (!(Test-Path -LiteralPath $SigningPropertiesPath -PathType Leaf)) {
    throw 'Falta la configuración privada de firma. Consulta docs/ANDROID_BETA.md; no generes otra clave para actualizar la beta.'
}
if (!$OutputDirectory) { $OutputDirectory = Join-Path $repo 'build/android-beta' }
$config = Get-Content -LiteralPath (Join-Path $repo 'config/firebase_dev.json') -Raw | ConvertFrom-Json
if ($config.APP_ENV -ne 'development' -or $config.PUSH_ENABLED -ne $true -or
    $config.PUSH_FIREBASE_PROJECT_ID -ne 'entrenaop-dev' -or
    $config.SUPABASE_URL -ne 'https://sxbxfjqgoddzhtcyhalw.supabase.co' -or
    !$config.SUPABASE_PUBLISHABLE_KEY) {
    throw 'La beta debe usar Dev con sus notificaciones activadas.'
}
$expectedSigner = (Get-Content -LiteralPath (Join-Path $repo 'config/android_beta_certificate.sha256') -Raw).Trim()
if ($expectedSigner -notmatch '^[0-9a-f]{64}$') { throw 'Huella pública de firma no válida.' }
$localProperties = Get-Content -LiteralPath (Join-Path $repo 'android/local.properties')
$sdkLine = $localProperties | Where-Object { $_ -match '^sdk\.dir=' } | Select-Object -First 1
if (!$sdkLine) { throw 'Falta sdk.dir en android/local.properties.' }
$sdk = $sdkLine.Substring('sdk.dir='.Length).Replace('\\', '\').Replace('\:', ':')
$buildTools = Get-ChildItem -LiteralPath (Join-Path $sdk 'build-tools') -Directory |
    Where-Object { $_.Name -match '^\d+\.\d+\.\d+$' } |
    Sort-Object { [version]$_.Name } -Descending | Select-Object -First 1
if (!$buildTools) { throw 'No se encuentran las herramientas Android de verificación.' }
$apksigner = Join-Path $buildTools.FullName 'apksigner.bat'
$aapt = Join-Path $buildTools.FullName 'aapt.exe'
$previousSigning = $env:ENTRENAOP_ANDROID_SIGNING_PROPERTIES
$previousJava = $env:JAVA_HOME
Push-Location $repo
try {
    $env:ENTRENAOP_ANDROID_SIGNING_PROPERTIES = (Resolve-Path -LiteralPath $SigningPropertiesPath).Path
    $androidJava = 'C:/Program Files/Android/Android Studio/jbr'
    if (Test-Path -LiteralPath $androidJava) { $env:JAVA_HOME = $androidJava }
    $revision = (& git rev-parse HEAD).Trim()
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo identificar la revisión.' }
    $sourcePaths = @('lib', 'assets', 'packages', 'android', 'ios', 'web', 'linux', 'macos', 'windows', 'pubspec.yaml', 'pubspec.lock', 'tools/run_app.dart')
    $sourceStatus = @(& git status --porcelain -- @sourcePaths)
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo comprobar el estado de las fuentes.' }
    & dart run tools/run_app.dart build apk --release --dart-define-from-file=config/firebase_dev.json
    if ($LASTEXITCODE -ne 0) { throw 'La compilación Android ha fallado.' }
    if ((& git rev-parse HEAD).Trim() -ne $revision) { throw 'Git cambió durante la compilación; repítela sobre la revisión actual.' }
    $apk = Join-Path $repo 'build/app/outputs/flutter-apk/app-release.apk'
    $signature = @(& $apksigner verify --verbose --print-certs $apk 2>&1)
    if ($LASTEXITCODE -ne 0) { throw 'La firma del APK no es válida.' }
    Assert-AndroidBetaSignature -Output ($signature -join "`n") -ExpectedSigner $expectedSigner
    $badging = @(& $aapt dump badging $apk)
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo inspeccionar la APK.' }
    $package = [regex]::Match(($badging -join "`n"), "package: name='([^']+)' versionCode='([^']+)' versionName='([^']+)'")
    if (!$package.Success -or $package.Groups[1].Value -ne 'com.entrenaOp.entrenaop' -or
        ($badging -join "`n") -match 'application-debuggable') {
        throw 'Identidad o modo de compilación Android inesperados.'
    }
    foreach ($permission in @('android.permission.INTERNET', 'android.permission.POST_NOTIFICATIONS')) {
        if (!(($badging -join "`n").Contains($permission))) { throw "Falta el permiso $permission." }
    }
    $resources = @(& $aapt dump --values resources $apk)
    if ($LASTEXITCODE -ne 0) { throw 'No se pudieron inspeccionar los recursos Firebase.' }
    foreach ($value in @($config.PUSH_FIREBASE_PROJECT_ID, $config.PUSH_FIREBASE_ANDROID_APP_ID)) {
        if (!(($resources -join "`n").Contains($value))) { throw 'Falta la configuración nativa Firebase Dev.' }
    }
    New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
    $version = $package.Groups[3].Value
    $build = $package.Groups[2].Value
    $outputApk = Join-Path $OutputDirectory "EntrenaOP-$version-$build.apk"
    Copy-Item -LiteralPath $apk -Destination $outputApk
    $hash = (Get-FileHash -LiteralPath $outputApk -Algorithm SHA256).Hash.ToLowerInvariant()
    [ordered]@{
        file = Split-Path $outputApk -Leaf
        package = $package.Groups[1].Value
        version = $version
        build = $build
        environment = 'development'
        supabaseProject = 'sxbxfjqgoddzhtcyhalw'
        firebaseProject = $config.PUSH_FIREBASE_PROJECT_ID
        pushEnabled = $true
        revision = $revision
        modifiedSources = $sourceStatus.Count -gt 0
        packagedAtUtc = [DateTime]::UtcNow.ToString('o')
        signerSha256 = $expectedSigner
        apkSha256 = $hash
    } | ConvertTo-Json | Set-Content -LiteralPath "$outputApk.json" -Encoding utf8
    Write-Output "APK verificada: $outputApk"
    Write-Output "SHA-256: $hash"
} finally {
    $env:ENTRENAOP_ANDROID_SIGNING_PROPERTIES = $previousSigning
    $env:JAVA_HOME = $previousJava
    Pop-Location
}
