param([switch]$Publish)
$ErrorActionPreference = 'Stop'

# El destino es fijo: estos ejemplos nunca forman parte de las migraciones de producción.
$demoProjectRef = 'sxbxfjqgoddzhtcyhalw'
$demoSql = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'seed.sql') -Raw -Encoding UTF8
$demoMarker = 'rollback; -- @demo-transaction-end'
if (($demoSql.Split($demoMarker).Count - 1) -ne 1) {
    throw 'El script debe contener un único cierre de transacción.'
}
$demoEnding = if ($Publish) { 'commit;' } else { 'rollback;' }
$demoSql = $demoSql.Replace($demoMarker, $demoEnding)
$demoTempPath = Join-Path ([IO.Path]::GetTempPath()) ('guided-demo-' + [guid]::NewGuid() + '.sql')
try {
    [IO.File]::WriteAllText($demoTempPath, $demoSql, [Text.UTF8Encoding]::new($false))
    & supabase db query --linked --project-ref $demoProjectRef --file $demoTempPath
    if ($LASTEXITCODE -ne 0) { throw 'La carga demo ha fallado; la transacción no se ha confirmado.' }
    if ($Publish) { Write-Output 'Demo publicada exclusivamente en desarrollo.' }
    else { Write-Output 'Ensayo correcto con ROLLBACK; no se han guardado datos.' }
} finally {
    if (Test-Path -LiteralPath $demoTempPath) { Remove-Item -LiteralPath $demoTempPath }
}
