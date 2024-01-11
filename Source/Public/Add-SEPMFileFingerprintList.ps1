function Add-SEPMFileFingerprintList {
    <#
    .SYNOPSIS
        Adds a blacklist as a file fingerprint list 
    .DESCRIPTION
        Adds a blacklist as a file fingerprint list
    .PARAMETER name
        The name of the blacklist to be added
    .PARAMETER domainId
        The domain id of the domain to add the blacklist to
        Only takes the domain id. Can be found using Get-SEPMDomain
    .PARAMETER HashType
        The type of hash to use for the blacklist
        Valid values are SHA256 and MD5
    .PARAMETER description
        The description of the blacklist
    .PARAMETER hashlist
        The hash list to add to the blacklist
        Can be generated using Get-FileHash or takes a string array of hashes
    .PARAMETER SkipCertificateCheck
        Skip certificate check
    .EXAMPLE
        $DomainId = Get-SEPMDomain | Where-Object { $_.name -eq "Default" }
        $HashList = ls -file C:\Users\$env:USERNAME\Downloads\*.exe | Get-FileHash -algorithm SHA256
        Add-SEPMFileFingerprintList -name "My Blacklist" -domainId $domainId -HashType "SHA256" -description "My Blacklist" -hashlist $hashlist.hash

        Gets the domain id for the default domain 
        Create a hash list of all the .exe files in the downloads folder of the currently logged in user
        Adds the hash list as a blacklist to the default domain
#>

    [CmdletBinding()]
    param (
        [Parameter()]
        [string]$name,

        [Parameter()]
        [string]$domainId,

        [Parameter()]
        [ValidateSet('SHA256', 'MD5')]
        [string]$HashType,

        [Parameter()]
        [string]$description,

        [Parameter()]
        $hashlist,

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
        $URI = $script:BaseURLv1 + "/policy-objects/fingerprints"

        # Construct the body & required fields
        $body = @{
            name        = $name
            domainId    = $domainId
            hashType    = $HashType
            description = $description
            data        = $hashlist
        }

        $params = @{
            Method      = 'POST'
            Uri         = $URI
            headers     = $headers
            Body        = $body | ConvertTo-Json
            ContentType = 'application/json'
        }
    
        $resp = Invoke-ABRestMethod -params $params
        return $resp
    }
}