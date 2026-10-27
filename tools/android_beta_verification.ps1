function Assert-AndroidBetaSignature {
    param([string]$Output, [string]$ExpectedSigner)
    $count = [regex]::Match($Output, '(?m)^Number of signers: (\d+)\r?$')
    # Build Tools 37 usa «V2 Signer:» donde versiones anteriores decían «Signer #1».
    # Solo se comparan certificados; la huella de la clave pública es diferente.
    $certificates = [regex]::Matches($Output,
        '(?m)^(?:Signer #\d+|V\d+(?:\.\d+)? Signer):? certificate SHA-256 digest: ([0-9a-fA-F]{64})\r?$')
    $digests = @($certificates | ForEach-Object { $_.Groups[1].Value.ToLowerInvariant() } | Sort-Object -Unique)
    if (!$count.Success -or $count.Groups[1].Value -ne '1' -or
        $digests.Count -ne 1 -or $digests[0] -ne $ExpectedSigner) {
        throw 'La APK no está firmada únicamente con la identidad estable de esta beta.'
    }
}
