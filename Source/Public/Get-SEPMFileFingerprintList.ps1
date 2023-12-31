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
    .PARAMETER SkipCertificateCheck
        Skip certificate check
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
        $FingerprintListID,

        # Skip certificate check
        [Parameter()]
        [switch]
        $SkipCertificateCheck
    )

    begin {
        # initialize the configuration
        $test_token = Test-SEPMAccessToken
        if (-not $test_token) {
            Get-SEPMAccessToken | Out-Null
        }
        if ($SkipCertificateCheck) {
            $script:SkipCert = $true
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
            $URI = Build-SEPMQueryURI -BaseURI $URI -QueryStrings $QueryStrings

            $params = @{
                Method  = 'GET'
                Uri     = $URI
                headers = $headers
            }
    
            $resp = Invoke-ABRestMethod -params $params
        }

        if ($FingerprintListID) {
            $URI = $script:BaseURLv1 + "/policy-objects/fingerprints/$FingerprintListID"
            
            # prepare the parameters
            $params = @{
                Method  = 'GET'
                Uri     = $URI
                headers = $headers
            }
    
            $resp = Invoke-ABRestMethod -params $params
        }
        
        # return the response
        return $resp
    }
}