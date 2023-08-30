function Save-SepmConfiguration {
    <#
    .SYNOPSIS
        Serializes the provided settings object to disk as a JSON file.

    .DESCRIPTION
        Serializes the provided settings object to disk as a JSON file.

        The Git repo for this module can be found here: http://aka.ms/PowerShellForGitHub

    .PARAMETER Configuration
        The configuration object to persist to disk.

    .PARAMETER Path
        The path to the file on disk that Configuration should be persisted to.

    .NOTES
        Internal helper method.

    .EXAMPLE
        Save-SepmConfiguration -Configuration $config -Path 'c:\foo\config.json'

        Serializes $config as a JSON object to 'c:\foo\config.json'
#>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject] $Configuration,

        [Parameter(Mandatory)]
        [string] $Path
    )

    if (-not $PSCmdlet.ShouldProcess('Sepm Configuration', 'Save')) {
        return
    }

    $null = New-Item -Path $Path -Force
    ConvertTo-Json -InputObject $Configuration |
        Set-Content -Path $Path -Force -ErrorAction SilentlyContinue -ErrorVariable ev

    if (($null -ne $ev) -and ($ev.Count -gt 0)) {
        $message = "Failed to persist these updated settings to disk.  They will remain for this PowerShell session only."
        Write-Warning -Message $message
    }
}