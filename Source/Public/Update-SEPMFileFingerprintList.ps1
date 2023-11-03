function Update-SEPMFileFingerprintList {
    <#
    .SYNOPSIS
        Updates an existing fingerprint list
    .DESCRIPTION
        Updates an existing fingerprint list
        When updating the list, overwrite the entire list with the new list
    .PARAMETER FingerprintListName
        The name of the file fingerprint list
        Cannot be used with FingerprintListID parameter
    .PARAMETER FingerprintListID
        The ID of the file fingerprint list
        Cannot be used with FingerprintListName parameter
    .PARAMETER name
        The name of the fingerprint list that will appear on SEPM
    .PARAMETER domainId
        The domain id of the domain to add the fingerprint list to
        Only takes the domain id. Can be found using Get-SEPMDomain
    .PARAMETER HashType
        The type of hash to use for the fingerprint list
        Valid values are SHA256 and MD5
    .PARAMETER description
        The description of the fingerprint list
    .PARAMETER hashlist
        The hash list to add to the fingerprint list
        Can be generated using Get-FileHash or takes a string array of hashes
    .EXAMPLE
        $domainId = Get-SEPMDomain | Where-Object { $_.name -eq "Default" } | Select-Object -ExpandProperty id
        $hashlist = ls -file C:\Users\$env:USERNAME\Downloads\*.exe | Get-FileHash -algorithm SHA256
        Update-SEPMFileFingerprintList -FingerprintListName "Downloaded .exe files" -name "Workstations downloaded files" -domainId $DomainId -HashType "SHA256" -description "Contains the list of .exe files downloaded with a specific workstations" -hashlist $hashlist.hash

        Gets the domain id for the default domain
        Create a hash list of all the files in the downloads folder of the currently logged in user
        Updates the fingerprint list "Downloaded .exe files" with the new hash list
        The fingerprint list needs to be existing before it can be updated
#>
    [CmdletBinding(
        DefaultParameterSetName = 'Name'
    )]
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

        [Parameter(
            ValueFromPipeline = $true
        )]
        $hashlist,

        [Parameter(
            ParameterSetName = 'Name'
        )]
        [string]
        $FingerprintListName,

        [Parameter(
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
    
        # Invoke the request
        # If the version of PowerShell is 6 or greater, then we can use the -SkipCertificateCheck parameter
        # else we need to use the Skip-Cert function if self-signed certs are being used.
        try {
            # Invoke the request params
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

        # return the response
        return $resp
    }
}