function Fix-DoubleEncodedUtf8 {
    <#
    .SYNOPSIS
        Repairs strings that have been double-encoded as UTF-8.
    .DESCRIPTION
        Some SEPM API fields come back with UTF-8 bytes that were incorrectly
        interpreted as Latin-1 and then re-encoded. This function detects and
        repairs such double-encoded strings.
    .PARAMETER InputString
        The potentially double-encoded string.
    .EXAMPLE
        Fix-DoubleEncodedUtf8 -InputString "CafÃ©"
        Returns "Café"
    #>
    param(
        [Parameter(ValueFromPipeline = $true)]
        [string]$InputString
    )

    process {
        if (-not $InputString) { return $InputString }

        try {
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($InputString)
            $decoded = [System.Text.Encoding]::UTF8.GetString($bytes)

            # If re-decoding changes the string, return decoded version
            if ($decoded -ne $InputString) {
                # Try Latin-1 → UTF-8 repair
                $latin1 = [System.Text.Encoding]::GetEncoding(28591)
                $utf8Bytes = $latin1.GetBytes($InputString)
                $repaired = [System.Text.Encoding]::UTF8.GetString($utf8Bytes)

                # Check if the repaired string has replacement characters (0xFFFD)
                if ($repaired -match '\uFFFD') {
                    return $InputString
                }
                return $repaired
            }
            return $InputString
        } catch {
            return $InputString
        }
    }
}
