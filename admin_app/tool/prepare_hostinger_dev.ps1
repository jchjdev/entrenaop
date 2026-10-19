param([switch]$SkipBuild)
$ErrorActionPreference = 'Stop'
$adminRoot = Split-Path -Parent $PSScriptRoot
Push-Location -LiteralPath $adminRoot
try {
  $revision = (git rev-parse --short HEAD).Trim()
  $buildStamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
  if (-not $SkipBuild) {
    flutter build web --release --csp --no-web-resources-cdn --no-source-maps --no-wasm-dry-run --dart-define=APP_ENV=development --dart-define=SUPABASE_URL=https://sxbxfjqgoddzhtcyhalw.supabase.co
    if ($LASTEXITCODE -ne 0) { throw 'Falló la compilación del admin Dev.' }
  }
  $sourceRoot = Join-Path $adminRoot 'build/web'
  if (-not (Test-Path -LiteralPath (Join-Path $sourceRoot 'index.html'))) { throw 'No existe el build web.' }
  $packageRoot = Join-Path $adminRoot "build/hostinger-dev/$revision-$buildStamp"
  New-Item -ItemType Directory -Path $packageRoot | Out-Null
  # Cada paquete usa una carpeta nueva; no se borra ni se sobrescribe una publicación previa.
  Get-ChildItem -LiteralPath $sourceRoot -Force | Copy-Item -Destination $packageRoot -Recurse -Force
  Copy-Item -LiteralPath (Join-Path $adminRoot 'deployment/hostinger-dev.htaccess') -Destination (Join-Path $packageRoot '.htaccess')
  Copy-Item -LiteralPath (Join-Path $adminRoot 'deployment/robots.txt') -Destination (Join-Path $packageRoot 'robots.txt')
  $sourceChanges = @(git status --porcelain -- lib web deployment tool pubspec.yaml pubspec.lock ../packages/workout_core ../packages/workout_editor_ui ../packages/entrena_ui)
  $metadata = @{ environment='development'; host='admin.entrenaop.es'; supabaseProject='sxbxfjqgoddzhtcyhalw'; revision=$revision; sourceTreeDirty=($sourceChanges.Count -gt 0); builtAtUtc=$buildStamp; mainJsSha256=(Get-FileHash -LiteralPath (Join-Path $packageRoot 'main.dart.js') -Algorithm SHA256).Hash }
  $metadata | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $packageRoot 'build-info.json') -Encoding utf8
  $unexpected = Get-ChildItem -LiteralPath $packageRoot -Recurse -Force -File | Where-Object { $_.Name -match '(^\.env|\.dart$|\.map$)' }
  if ($unexpected) { throw 'El paquete contiene fuentes, mapas o archivos de entorno. No se ha preparado el ZIP.' }
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $zipPath = "$packageRoot.zip"
  [System.IO.Compression.ZipFile]::CreateFromDirectory($packageRoot, $zipPath)
  $zip = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
  try {
    foreach ($required in @('index.html','.htaccess','robots.txt','main.dart.js','build-info.json')) {
      if (-not ($zip.Entries.FullName -contains $required)) { throw "Falta $required en el ZIP." }
    }
  } finally { $zip.Dispose() }
  [pscustomobject]@{ package=$zipPath; sha256=(Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash; environment='development' } | ConvertTo-Json
} finally { Pop-Location }
