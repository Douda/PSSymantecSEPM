function Send-SEPMCommand {
    <#
    .SYNOPSIS
        Sends a command to SEP endpoints through the command queue.
    .DESCRIPTION
        Sends a command to SEP endpoints through the command queue.
        Uses a registry-driven dispatch to select the target endpoint based on -Type.
        Supports ActiveScan, FullScan, Quarantine, and UpdateContent via -ComputerName.
    .PARAMETER Type
        The type of command to send (ActiveScan, FullScan, Quarantine, UpdateContent).
    .PARAMETER ComputerName
        The name of the computer(s) to send the command to.
    .PARAMETER Undo
        When used with -Type Quarantine, unquarantines the endpoint instead of quarantining.
    .EXAMPLE
        Send-SEPMCommand -Type ActiveScan -ComputerName "PC1"
    .EXAMPLE
        Send-SEPMCommand -Type Quarantine -ComputerName "PC1" -Undo
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet('ActiveScan', 'FullScan', 'Quarantine', 'UpdateContent')]
        [string]$Type,

        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'ComputerName'
        )]
        [Alias("Hostname", "DeviceName", "Device", "Computer")]
        [string[]]$ComputerName,

        [Parameter()]
        [switch]$Undo
    )

    begin {
        $session = Initialize-SEPMSession

        $commandRegistry = @{
            ActiveScan    = @{ Path = 'activescan' }
            FullScan      = @{ Path = 'fullscan' }
            Quarantine    = @{ Path = 'quarantine'; Params = @{ Undo = 'undo' } }
            UpdateContent = @{ Path = 'updatecontent' }
        }
    }

    process {
        $targets = Resolve-SepmCommandTarget -ComputerName $ComputerName

        $queryStrings = @{
            computer_ids = $targets.computer_ids
        }

        $entry = $commandRegistry[$Type]
        if ($entry.ContainsKey('Params')) {
            foreach ($paramName in $entry.Params.Keys) {
                if ($PSBoundParameters.ContainsKey($paramName)) {
                    $queryStrings[$entry.Params[$paramName]] = $PSBoundParameters[$paramName]
                }
            }
        }

        $URI = $session.BaseURLv1 + '/command-queue/' + $entry.Path
        $URI = Build-SEPMQueryURI -BaseURI $URI -QueryStrings $queryStrings

        $resp = Invoke-SepmApi -Method 'POST' -Uri $URI -Session $session

        Write-Output $resp -NoEnumerate
    }
}
