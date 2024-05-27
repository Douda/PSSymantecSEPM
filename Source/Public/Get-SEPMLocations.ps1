function Get-SEPMLocations {
    <# TODO update help for Location
    .SYNOPSIS
        Gets a list of locations for a specific group
    .DESCRIPTION
        Gets a list of locations for a specific group
    .PARAMETER SkipCertificateCheck
        Skip certificate check
    .PARAMETER GroupID
        Mandatory parameter for the group ID
    .EXAMPLE
        PS C:\PSSymantecSEPM> Get-SEPMLocations -GroupID "XXXXXXXX"

        name                  id
        ----                  --
        Default               33CE4894AC1485D12E3AAC763CF9A71B
        Location 1 - Internal 0CCB0536AC1485D1233F341B9495C3C5
        Location 2 - VPN      F5E857C9AC1485D13095A0D6E1CD5B25

        Gets the list of location names and their IDs for the specified group
    .EXAMPLE
        PS C:\PSSymantecSEPM> Get-SEPMLocations -GroupID "XXXXXXXX" | Select-Object -First 1

        name                  id
        ----                  --
        Default               33CE4894AC1485D12E3AAC763CF9A71B

        Gets the first location of the list of locations for the specified group
#>

    [CmdletBinding()]
    param (
        # Skip certificate check
        [Parameter()]
        [switch]
        $SkipCertificateCheck,

        # GroupID
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true
        )]
        [String]
        $GroupID
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
        $allGroupsInfo = Get-SEPMGroups
    }

    process {
        # Get Group info
        $groupInfo = $allGroupsInfo | Where-Object { $_.id -eq $GroupID }

        $URI = $script:BaseURLv1 + "/groups" + "/$GroupID/locations"
        $locationList = @()

        # prepare the parameters
        $params = @{
            Method  = 'GET'
            Uri     = $URI
            headers = $headers
        }

        # QueryString parameters
        $QueryStrings = @{
            hasName = $true
        }
    
        # Invoke the request
        $URI = Build-SEPMQueryURI -BaseURI $URI -QueryStrings $QueryStrings
        $params = @{
            Method  = 'GET'
            Uri     = $URI
            headers = $headers
        }
                
        $resp = Invoke-ABRestMethod -params $params

        # parse response and add group information to the list
        foreach ($location in $resp) {
            $locationList += [PSCustomObject]@{
                locationName      = $location.split(":")[0]
                locationId        = $location.split("/")[-1]
                groupName         = $groupInfo.name
                groupId           = $groupInfo.id
                groupFullPathName = $groupInfo.fullPathName
            }
        }

        # return the response
        return $locationList
    }
}