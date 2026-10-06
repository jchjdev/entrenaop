# Regenera los recursos nativos desde el PNG oficial, sin dependencias de Flutter.
# Ejecutar en Windows: powershell -File tools/generate_app_icons.ps1
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$projectRoot = Split-Path -Parent $PSScriptRoot
$sourcePath = Join-Path $projectRoot 'assets/branding/entrenaop_app_icon_full_bleed.png'
$source = [System.Drawing.Image]::FromFile($sourcePath)
$generated = 0

function Write-Icon {
    param([string]$RelativePath, [int]$Size, [double]$ArtworkScale = 1, [switch]$Transparent)

    $path = Join-Path $projectRoot $RelativePath
    [System.IO.Directory]::CreateDirectory((Split-Path -Parent $path)) | Out-Null
    # iOS exige un PNG opaco. Solo la capa adaptable de Android lleva transparencia.
    $format = [System.Drawing.Imaging.PixelFormat]::Format24bppRgb
    if ($Transparent) { $format = [System.Drawing.Imaging.PixelFormat]::Format32bppArgb }
    $bitmap = [System.Drawing.Bitmap]::new($Size, $Size, $format)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $attributes = [System.Drawing.Imaging.ImageAttributes]::new()
    try {
        # Los márgenes de seguridad también son oscuros, nunca blancos.
        $background = [System.Drawing.Color]::FromArgb(9, 10, 13)
        if ($Transparent) { $background = [System.Drawing.Color]::Transparent }
        $graphics.Clear($background)
        $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $attributes.SetWrapMode([System.Drawing.Drawing2D.WrapMode]::TileFlipXY)
        $artworkSize = [int][Math]::Round($Size * $ArtworkScale)
        $offset = [int][Math]::Floor(($Size - $artworkSize) / 2)
        $rectangle = [System.Drawing.Rectangle]::new($offset, $offset, $artworkSize, $artworkSize)
        $graphics.DrawImage($source, $rectangle, 0, 0, $source.Width, $source.Height,
            [System.Drawing.GraphicsUnit]::Pixel, $attributes)
        $bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
        $script:generated++
    }
    finally {
        $attributes.Dispose()
        $graphics.Dispose()
        $bitmap.Dispose()
    }
}

try {
    if ($source.Width -ne $source.Height) { throw 'El icono oficial debe ser cuadrado.' }
    $densities = @{ mdpi = 48; hdpi = 72; xhdpi = 96; xxhdpi = 144; xxxhdpi = 192 }
    foreach ($density in $densities.Keys) {
        Write-Icon "android/app/src/main/res/mipmap-$density/ic_launcher.png" $densities[$density]
    }
    # Capa de 108 dp a densidad xxxhdpi. Las letras quedan dentro de los 66 dp seguros.
    Write-Icon 'android/app/src/main/res/drawable-xxxhdpi/ic_launcher_foreground.png' 432 (2.0 / 3.0) -Transparent

    $catalogPath = Join-Path $projectRoot 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json'
    $catalog = Get-Content -LiteralPath $catalogPath -Raw | ConvertFrom-Json
    foreach ($entry in ($catalog.images | Sort-Object filename -Unique)) {
        $points = [double]::Parse(($entry.size -split 'x')[0], [Globalization.CultureInfo]::InvariantCulture)
        $scale = [int]($entry.scale -replace 'x', '')
        Write-Icon "ios/Runner/Assets.xcassets/AppIcon.appiconset/$($entry.filename)" ([int]($points * $scale))
    }

    Write-Icon 'web/favicon.png' 48
    foreach ($size in @(192, 512)) {
        Write-Icon "web/icons/Icon-$size.png" $size
        # Margen para mantener las letras en el círculo seguro del icono web instalable.
        Write-Icon "web/icons/Icon-maskable-$size.png" $size 0.85
    }
    Write-Output "Generados $generated recursos desde el icono oficial."
}
finally { $source.Dispose() }
