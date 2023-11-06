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
        $FingerprintListID
    )

    begin {
        # initialize the configuration
        $test_token = Test-SEPMAccessToken
        if ($test_token -eq $false) {
            Get-SEPMAccessToken | Out-Null
        }
        
        $headers = @{
            "Authorization" = "Bearer " + $script:accessToken.token
            "Content"       = 'application/json'
        }
    }

    process {
        # Get the FingerprintListID if the FingerprintListName is provided
        if ($FingerprintListName) {
            $URI = $script:BaseURLv1 + "/policy-objects/fingerprints"
            $FingerprintListID = Get-SEPMFileFingerprintList -FingerprintListName $FingerprintListName | Select-Object -ExpandProperty id
        }

        $URI = $script:BaseURLv1 + "/policy-objects/fingerprints/$FingerprintListID"

        $params = @{
            Method  = 'DELETE'
            Uri     = $URI
            headers = $headers
        }

        $resp = Invoke-ABRestMethod -params $params

        # return the response
        return $resp
    }
}