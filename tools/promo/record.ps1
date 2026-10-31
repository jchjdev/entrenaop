$ErrorActionPreference = 'Stop'
$taskRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$originalLocation = Get-Location
$originalOutput = $env:PROMO_OUTPUT
$originalFonts = $env:FLUTTER_FONT_DIR
$flutterCommand = (Get-Command flutter -ErrorAction Stop).Source
$sdkRoot = Split-Path (Split-Path $flutterCommand -Parent) -Parent
$env:FLUTTER_FONT_DIR = Join-Path $sdkRoot 'bin/cache/artifacts/material_fonts'
$take = Join-Path $taskRoot ('build/promo/take-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
$assets = Join-Path $taskRoot 'website/next/assets'
Get-Command ffmpeg -ErrorAction Stop | Out-Null

try {
  foreach ($clip in @('athlete', 'trainer')) {
    $env:PROMO_OUTPUT = Join-Path $take $clip
    if ($clip -eq 'athlete') {
      Set-Location $taskRoot
      & $flutterCommand test --no-pub tools/promo/record_athlete_test.dart --reporter expanded
    } else {
      Set-Location (Join-Path $taskRoot 'trainer_app')
      & $flutterCommand test --no-pub tool/promo/record_trainer_test.dart --reporter expanded
    }
    if ($LASTEXITCODE -ne 0) { throw "Falló la captura de $clip; no se exporta el vídeo." }
    $manifest = Join-Path $env:PROMO_OUTPUT 'frames.ffconcat'
    $video = Join-Path $assets "$clip-demo.mp4"
    $poster = Join-Path $assets "$clip-demo-poster.webp"
    & ffmpeg -hide_banner -loglevel warning -f concat -safe 0 -i $manifest -an -c:v libx264 -preset medium -crf 21 -pix_fmt yuv420p -r 20 -fps_mode cfr -movflags +faststart -y $video
    if ($LASTEXITCODE -ne 0) { throw "Falló la exportación de $clip." }
    & ffmpeg -hide_banner -loglevel warning -i $video -frames:v 1 -c:v libwebp -quality 85 -y $poster
    if ($LASTEXITCODE -ne 0) { throw "Falló el póster de $clip." }
  }
  Write-Host "Vídeos locales preparados en $assets"
  Write-Host "Fotogramas originales conservados en $take"
} finally {
  Set-Location $originalLocation
  $env:PROMO_OUTPUT = $originalOutput
  $env:FLUTTER_FONT_DIR = $originalFonts
}
