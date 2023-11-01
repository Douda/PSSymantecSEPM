function Get-SEPMFileFingerprintList {
    <# TODO update help
    .SYNOPSIS
        Get File Finger Print List By Name
    .DESCRIPTION
        Gets the file fingerprint list for a specified Name as a set of hash values
    .PARAMETER FingerprintListName
        The name of the file fingerprint list
    .PARAMETER FingerprintListID
        The ID of the file fingerprint list
    .EXAMPLE
        PS C:\PSSymantecSEPM> Get-SEPMFileFingerprintList -FingerprintListName "Fingerprint list for workstations"

        id          : 2A331150CDB44B9A9F1332E27321A1EE
        name        : Fingerprint list for workstations
        hashType    : MD5
        source      : WEBSERVICE
        description : 
        data        : {01BCE403043C0695EBB04D89C2B3A027, 03F3C0A7A2DD4EE1E81FABDBC557E2E8, 043A1B77C731F053FCA5DCC4AA18838F, 07996DCEEA57D8615B91A48AA7B49EC3…}
        groupIds    : {46B9A36B0A66062224C839F606E6B1CE, AD3CD4620A95B05502CBDB658A6F7BE3, 09CC40530A6606221853DEA0AC606451, 96017A1E0A6906231EFEACCBD915B592…}

        Gets the file fingerprint list for a specified Name as a set of hash values
    .EXAMPLE
        PS C:\PSSymantecSEPM> Get-SEPMFileFingerprintList -FingerprintListID 2A331150CDB44B9A9F1332E27321A1EE

        id          : 2A331150CDB44B9A9F1332E27321A1EE
        name        : ASD01P0215
        hashType    : MD5
        source      : WEBSERVICE
        description : 
        data        : {01BCE403043C0695EBB04D89C2B3A027, 03F3C0A7A2DD4EE1E81FABDBC557E2E8, 043A1B77C731F053FCA5DCC4AA18838F, 07996DCEEA57D8615B91A48AA7B49EC3…}
        groupIds    : {46B9A36B0A66062224C839F606E6B1CE, AD3CD4620A95B05502CBDB658A6F7BE3, 09CC40530A6606221853DEA0AC606451, 96017A1E0A6906231EFEACCBD915B592…}

        Gets the file fingerprint list for a specified ID as a set of hash values
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
        }

        if ($FingerprintListID) {
            $URI = $script:BaseURLv1 + "/policy-objects/fingerprints/$FingerprintListID"
            # URI query strings
            $QueryStrings = @{}

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
        }
        

        # return the response
        return $resp
    }
}