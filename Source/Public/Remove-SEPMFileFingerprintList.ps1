function Remove-SEPMFileFingerprintList {
    <#
    .SYNOPSIS
        Deletes a file fingerprint list
    .DESCRIPTION
        Deletes a file fingerprint list, and removes it from a group to which it applies
    .PARAMETER FingerprintListName
        The name of the file fingerprint list
    .PARAMETER FingerprintListID
        The ID of the file fingerprint list
    .EXAMPLE
        PS C:\PSSymantecSEPM> Remove-SEPMFileFingerprintList -FingerprintListName "Fingerprint list for workstations"

        Removes the file fingerprint list with the name "Fingerprint list for workstations"
    .EXAMPLE
        PS C:\PSSymantecSEPM> "Fingerprint list for workstations" | Remove-SEPMFileFingerprintList

        Removes the file fingerprint list with the name "Fingerprint list for workstations" via the pipeline
    .EXAMPLE
        PS C:\PSSymantecSEPM> Remove-SEPMFileFingerprintList -FingerprintListID 2A331150CDB44B9A9F1332E27321A1EE

        Removes the file fingerprint list with the ID "2A331150CDB44B9A9F1332E27321A1EE"
#>

    [CmdletBinding(
        DefaultParameterSetName = 'Name'
    )]
    param (
        [Parameter(
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'Name'
        )]
        [string]
        $FingerprintListName,

        [Parameter(
            ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'ID'
        )]
        [string]
        $FingerprintListID,

        [Parameter()]
        [switch]
        $PassThru
    )

    begin {
        $session = Initialize-SEPMSession
        $endpoint = Get-SEPMApiEndpoint -OperationName 'Remove-SEPMFileFingerprintList'
    }

    process {
        # Get the FingerprintListID if the FingerprintListName is provided
        if ($FingerprintListName) {
            $fp = Get-SEPMFileFingerprintList -FingerprintListName $FingerprintListName | Select-Object -First 1
            $FingerprintListID = if ($fp) { $fp.id } else { $null }
        }

        $resp = Invoke-SepmEndpoint -Endpoint $endpoint -Session $session -PathIds @($FingerprintListID)

        if ($PassThru) {
            Write-Output $resp
        }
    }
}
