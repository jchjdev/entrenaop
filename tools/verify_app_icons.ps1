# Comprueba tamaños, referencias, ausencia de blanco, opacidad y zonas seguras.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$projectRoot = Split-Path -Parent $PSScriptRoot
$checked = 0

function Test-Icon {
    param([string]$RelativePath, [int]$Size, [double]$SafeRadius = 0, [switch]$Opaque)
    $path = Join-Path $projectRoot $RelativePath
    $bitmap = [System.Drawing.Bitmap]::new($path)
    try {
        if ($bitmap.Width -ne $Size -or $bitmap.Height -ne $Size) {
            throw "Tamaño incorrecto: $RelativePath"
        }
        if ($Opaque) {
            # El byte 25 de IHDR declara el tipo de color PNG: 2 es RGB sin alfa.
            $bytes = [System.IO.File]::ReadAllBytes($path)
            if ($bytes[25] -ne 2) { throw "El icono debe ser RGB opaco: $RelativePath" }
        }
        $center = ($Size - 1) / 2.0
        $limit = $Size * $SafeRadius
        for ($y = 0; $y -lt $Size; $y++) {
            for ($x = 0; $x -lt $Size; $x++) {
                $pixel = $bitmap.GetPixel($x, $y)
                if ($pixel.A -gt 16 -and $pixel.R -gt 180 -and $pixel.G -gt 180 -and $pixel.B -gt 180) {
                    throw "Marco o fondo claro en el icono: $RelativePath ($x, $y)"
                }
                # El naranja identifica las letras, no el fondo negro/blanco.
                if ($SafeRadius -gt 0 -and $pixel.A -gt 128 -and $pixel.R -gt 180 -and $pixel.G -lt 245 -and $pixel.B -lt 100) {
                    $distance = [Math]::Sqrt([Math]::Pow($x - $center, 2) + [Math]::Pow($y - $center, 2))
                    if ($distance -gt $limit) { throw "Letras fuera de zona segura: $RelativePath ($x, $y)" }
                }
            }
        }
        $script:checked++
    }
    finally { $bitmap.Dispose() }
}

$densities = @{ mdpi = 48; hdpi = 72; xhdpi = 96; xxhdpi = 144; xxxhdpi = 192 }
foreach ($density in $densities.Keys) {
    Test-Icon "android/app/src/main/res/mipmap-$density/ic_launcher.png" $densities[$density]
}
Test-Icon 'android/app/src/main/res/drawable-xxxhdpi/ic_launcher_foreground.png' 432 (33.0 / 108.0)
$androidManifest = [xml](Get-Content (Join-Path $projectRoot 'android/app/src/main/AndroidManifest.xml') -Raw)
if ($androidManifest.manifest.application.GetAttribute('icon', 'http://schemas.android.com/apk/res/android') -ne '@mipmap/ic_launcher') {
    throw 'Android no referencia ic_launcher.'
}
$adaptive = [xml](Get-Content (Join-Path $projectRoot 'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml') -Raw)
if ($adaptive.'adaptive-icon'.foreground.GetAttribute('drawable', 'http://schemas.android.com/apk/res/android') -ne '@drawable/ic_launcher_foreground') {
    throw 'La capa adaptable no referencia el PNG generado.'
}
$colors = [xml](Get-Content (Join-Path $projectRoot 'android/app/src/main/res/values/ic_launcher_background.xml') -Raw)
if ($colors.resources.color.name -ne 'ic_launcher_background' -or $colors.resources.color.InnerText -ne '#090A0D') {
    throw 'El fondo adaptable debe ser oscuro, sin marco blanco.'
}

$catalog = Get-Content (Join-Path $projectRoot 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json') -Raw | ConvertFrom-Json
foreach ($entry in $catalog.images) {
    $points = [double]::Parse(($entry.size -split 'x')[0], [Globalization.CultureInfo]::InvariantCulture)
    $scale = [int]($entry.scale -replace 'x', '')
    Test-Icon "ios/Runner/Assets.xcassets/AppIcon.appiconset/$($entry.filename)" ([int]($points * $scale)) -Opaque
}

Test-Icon 'web/favicon.png' 48
$manifest = Get-Content (Join-Path $projectRoot 'web/manifest.json') -Raw | ConvertFrom-Json
foreach ($entry in $manifest.icons) {
    $size = [int]($entry.sizes -split 'x')[0]
    $radius = 0
    if ($entry.purpose -eq 'maskable') { $radius = 0.4 }
    Test-Icon "web/$($entry.src)" $size $radius -Opaque
}
$html = Get-Content (Join-Path $projectRoot 'web/index.html') -Raw
if ($html -notmatch 'href="favicon.png\?v=op2"' -or $html -notmatch 'href="icons/Icon-192.png"') {
    throw 'La página no referencia los iconos web esperados.'
}
# La regresión debe detectar expresamente el marco del PNG original descartado.
$original = [System.Drawing.Image]::FromFile((Join-Path $projectRoot 'assets/branding/entrenaop_app_icon.png'))
$originalSize = $original.Width
$original.Dispose()
$detectedOriginalBorder = $false
try { Test-Icon 'assets/branding/entrenaop_app_icon.png' $originalSize }
catch {
    if ($_.Exception.Message -notlike 'Marco o fondo claro*') { throw }
    $detectedOriginalBorder = $true
}
if (-not $detectedOriginalBorder) { throw 'La comprobación no detecta el marco blanco del original.' }
Write-Output "Verificadas $checked referencias, ausencia de blanco, opacidad y zonas seguras; regresión del marco original detectada."
