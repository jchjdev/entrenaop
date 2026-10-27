$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '../android_beta_verification.ps1')
$expected = 'a' * 64
$other = 'b' * 64
foreach ($label in @('Signer #1', 'V2 Signer:', 'V3.1 Signer:')) {
    Assert-AndroidBetaSignature -Output "Number of signers: 1`n$label certificate SHA-256 digest: $expected" -ExpectedSigner $expected
}
# Varios esquemas del mismo certificado no equivalen a varios firmantes.
Assert-AndroidBetaSignature -Output "Number of signers: 1`r`nV2 Signer: certificate SHA-256 digest: $expected`r`nV3 Signer: certificate SHA-256 digest: $expected`r`n" -ExpectedSigner $expected
$invalid = @(
    "Number of signers: 1`nV2 Signer: certificate SHA-256 digest: $other",
    "Number of signers: 2`nSigner #1 certificate SHA-256 digest: $expected`nSigner #2 certificate SHA-256 digest: $other",
    "Number of signers: 1`nV2 Signer: public key SHA-256 digest: $expected",
    "V2 Signer: certificate SHA-256 digest: $expected",
    "Number of signers: 1`nFormato de certificado desconocido"
)
foreach ($output in $invalid) {
    $rejected = $false
    try { Assert-AndroidBetaSignature -Output $output -ExpectedSigner $expected } catch { $rejected = $true }
    if (!$rejected) { throw 'Se aceptó una firma inesperada, múltiple o sin identificar.' }
}
Write-Output '9 comprobaciones de identidad de firma correctas.'
