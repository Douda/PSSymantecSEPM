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

    [CmdletBinding()]
    param (
        [Parameter(
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [string]
        $FingerprintListName,

        [Parameter(
            ValueFromPipelineByPropertyName = $true
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
        if ($FingerprintListName) {
            # Gathers fingerprint list ID from its name
            $URI = $script:BaseURLv1 + "/policy-objects/fingerprints"
            # URI query strings
            $QueryStrings = @{
                name = $FingerprintListName
            }

            # Construct the URI
            $builder = New-Object System.UriBuilder($URI)
            $query = [System.Web.HttpUtility]::ParseQueryString($builder.Query)
            foreach ($param in $QueryStrings.GetEnumerator()) {
                $query[$param.Key] = $param.Value
            }
            $builder.Query = $query.ToString()
            $URI = $builder.ToString()

            $params = @{
                Method  = 'GET'
                Uri     = $URI
                headers = $headers
            }
    
            # Invoke the request
            # If the version of PowerShell is 6 or greater, then we can use the -SkipCertificateCheck parameter
            # else we need to use the Skip-Cert function if self-signed certs are being used.
            try {
                # Invoke the request params
                $params = @{
                    Method  = 'GET'
                    Uri     = $URI
                    headers = $headers
                }
                if ($script:accessToken.skipCert -eq $true) {
                    if ($PSVersionTable.PSVersion.Major -lt 6) {
                        Skip-Cert
                        $resp = Invoke-RestMethod @params
                    } else {
                        $resp = Invoke-RestMethod @params -SkipCertificateCheck
                    }
                } else {
                    $resp = Invoke-RestMethod @params
                } 
            } catch {
                Write-Warning -Message "Error: $_"
            }

            $FingerprintListID = $resp.id
        }

        if ($FingerprintListID) {
            $URI = $script:BaseURLv1 + "/policy-objects/fingerprints/$FingerprintListID"
            # URI query strings
            $QueryStrings = @{
                id = $FingerprintListID
            }

            # Construct the URI
            $builder = New-Object System.UriBuilder($URI)
            $query = [System.Web.HttpUtility]::ParseQueryString($builder.Query)
            foreach ($param in $QueryStrings.GetEnumerator()) {
                $query[$param.Key] = $param.Value
            }
            $builder.Query = $query.ToString()
            $URI = $builder.ToString()

            # Invoke the request
            # If the version of PowerShell is 6 or greater, then we can use the -SkipCertificateCheck parameter
            # else we need to use the Skip-Cert function if self-signed certs are being used.
            try {
                # Invoke the request params
                $params = @{
                    Method  = 'DELETE'
                    Uri     = $URI
                    headers = $headers
                }
                if ($script:accessToken.skipCert -eq $true) {
                    if ($PSVersionTable.PSVersion.Major -lt 6) {
                        Skip-Cert
                        $resp = Invoke-RestMethod @params
                    } else {
                        $resp = Invoke-RestMethod @params -SkipCertificateCheck
                    }
                } else {
                    $resp = Invoke-RestMethod @params
                } 
            } catch {
                Write-Warning -Message "Error: $_"
            }
        }

        # return the response
        return $resp
    }
}