function Export-SEPMInventory {
    <#
    .SYNOPSIS
        Exports an inventory snapshot of the SEPM environment.

    .DESCRIPTION
        Gathers data from multiple SEPM cmdlets into a single snapshot object,
        writes per-category .clixml files, and a timestamped snapshot blob.
        Failures from individual sub-cmdlets are captured rather than propagated.

    .PARAMETER OutputDir
        Directory where exported files are written. Default: current directory ('.').

    .PARAMETER DelayMs
        Delay in milliseconds between sub-cmdlet calls to reduce API load. Default: 0.

    .EXAMPLE
        PS C:\> Export-SEPMInventory -OutputDir 'C:\inventory'

        Gathers SEPM data and writes clixml exports to C:\inventory.
    #>

    [CmdletBinding()]
    param(
        [string]$OutputDir = '.',
        [int]$DelayMs = 0
    )

    begin {
        if (-not (Test-Path -Path $OutputDir)) {
            New-Item -Path $OutputDir -ItemType Directory -Force | Out-Null
        }

        $snapshot = [PSCustomObject]@{
            FetchedAt = [DateTime]::UtcNow
            Version   = $null
            Domains   = $null
            Failures  = @()
        }
        $snapshot.PSObject.TypeNames.Insert(0, 'SEPM.Inventory')
    }

    process {
        # Version
        try {
            $snapshot.Version = Get-SEPMVersion
        } catch {
            $snapshot.Failures += [PSCustomObject]@{
                Category = 'Version'
                Error    = $_.Exception.Message
            }
            [PSCustomObject]@{ Error = $_.Exception.Message } |
                Export-Clixml -Path (Join-Path -Path $OutputDir -ChildPath 'Version_failed.xml') -Force
        }

        if ($DelayMs -gt 0) { Start-Sleep -Milliseconds $DelayMs }

        # Domains
        try {
            $snapshot.Domains = Get-SEPMDomain
        } catch {
            $snapshot.Failures += [PSCustomObject]@{
                Category = 'Domains'
                Error    = $_.Exception.Message
            }
            [PSCustomObject]@{ Error = $_.Exception.Message } |
                Export-Clixml -Path (Join-Path -Path $OutputDir -ChildPath 'Domains_failed.xml') -Force
        }

        # Write per-category .clixml files
        if ($snapshot.Version) {
            $snapshot.Version | Export-Clixml -Path (Join-Path -Path $OutputDir -ChildPath 'all_version.xml') -Force
        }
        if ($snapshot.Domains) {
            $snapshot.Domains | Export-Clixml -Path (Join-Path -Path $OutputDir -ChildPath 'all_domains.xml') -Force
        }

        # Write timestamped snapshot blob
        $timestamp = $snapshot.FetchedAt.ToString('yyyy-MM-ddTHH-mm-ss')
        $snapshot | Export-Clixml -Path (Join-Path -Path $OutputDir -ChildPath "SepmInventory_$timestamp.clixml") -Force

        $snapshot
    }
}
