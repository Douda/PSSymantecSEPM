function Send-SEPMCommand {
    <#
    .SYNOPSIS
        Sends a command to SEP endpoints through the command queue.
    .DESCRIPTION
        Sends a command to SEP endpoints through the command queue.
        Uses a registry-driven dispatch to select the target endpoint based on -Type.
        Currently supports ActiveScan via -ComputerName.
    .PARAMETER Type
        The type of command to send (e.g., ActiveScan).
    .PARAMETER ComputerName
        The name of the computer(s) to send the command to.
    .EXAMPLE
        Send-SEPMCommand -Type ActiveScan -ComputerName "PC1"
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet('ActiveScan')]
        [string]$Type,

        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'ComputerName'
        )]
        [Alias("Hostname", "DeviceName", "Device", "Computer")]
        [string[]]$ComputerName
    )

    begin {
        $session = Initialize-SEPMSession

        $script:CommandRegistry = @{
            ActiveScan = @{ Path = 'activescan' }
        }
    }

    process {
        $entry = $script:CommandRegistry[$Type]

        # Resolve target computer names to IDs
        $targets = Resolve-SepmCommandTarget -ComputerName $ComputerName

        # Build the URI
        $URI = $session.BaseURLv1 + "/command-queue/" + $entry.Path
        $QueryStrings = @{
            computer_ids = $targets.computer_ids
        }
        $URI = Build-SEPMQueryURI -BaseURI $URI -QueryStrings $QueryStrings

        # POST to the command queue
        $resp = Invoke-SepmApi -Method 'POST' -Uri $URI -Session $session

        Write-Output $resp -NoEnumerate
    }
}
