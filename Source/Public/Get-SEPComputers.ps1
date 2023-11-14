function Get-SEPComputers {
    <#
    .SYNOPSIS
        Gets the information about the computers in a specified domain
    .DESCRIPTION
        Gets the information about the computers in a specified domain. either from computer names or group names
    .PARAMETER ComputerName
        Specifies the name of the computer for which you want to get the information. Supports wildcards
    .PARAMETER GroupName
        Specifies the group full path name for which you want to get the information. Supports wildcards
    .PARAMETER IncludeSubGroups
        Specifies whether to include subgroups when querying by group name
    .EXAMPLE
        Get-SEPComputers

        Gets computer details for all computers in the domain
    .EXAMPLE
        "MyComputer1","MyComputer2" | Get-SEPComputers

        Gets computer details for the specified computer MyComputer via pipeline
    .EXAMPLE
        Get-SEPComputers -ComputerName "MyComputer*"

        Gets computer details for all computer names starting by MyComputer
    .EXAMPLE
        Get-SEPComputers -GroupName "My Company\EMEA\Workstations"

        Gets computer details for all computers in the specified group MyGroup
    .EXAMPLE
        Get-SEPComputers -GroupName "My Company\EMEA\Workstations" -IncludeSubGroups

        Gets computer details for all computers in the specified group MyGroup and its subgroups
#>
    [CmdletBinding(
        DefaultParameterSetName = 'ComputerName'
    )]
    Param (
        # ComputerName
        [Parameter(
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'ComputerName'
        )]
        [Alias("Hostname", "DeviceName", "Device", "Computer")]
        [String]
        $ComputerName,

        # group name
        [Parameter(
            ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'GroupName'
        )]
        [Alias("Group")]
        [String]
        $GroupName,

        # switch parameter to include subgroups
        [Parameter(
            ParameterSetName = 'GroupName'
        )]
        [switch]
        $IncludeSubGroups,

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

        # Using computer name API call
        if ($ComputerName) {
            $allResults = @()
            $URI = $script:BaseURLv1 + "/computers"

            # URI query strings
            $QueryStrings = @{
                sort         = "COMPUTER_NAME"
                pageIndex    = 1
                pageSize     = 100
                computerName = $ComputerName
            }

            # Construct the URI
            $URI = Build-SEPMQueryURI -BaseURI $URI -QueryStrings $QueryStrings

            do {
                # Invoke the request params
                $params = @{
                    Method  = 'GET'
                    Uri     = $URI
                    headers = $headers
                }

                $resp = Invoke-ABRestMethod -params $params
                
                # Process the response
                $allResults += $resp.content

                # Increment the page index & update URI
                $QueryStrings.pageIndex++
                $URI = Build-SEPMQueryURI -BaseURI $URI -QueryStrings $QueryStrings
            } until ($resp.lastPage -eq $true)

            # return the response
            return $allResults
        }

        # Using computer name API call then filtering
        elseif ($GroupName) {
            $allResults = @()
            $URI = $script:BaseURLv1 + "/computers"

            # URI query strings
            $QueryStrings = @{
                sort         = "COMPUTER_NAME"
                pageIndex    = 1
                pageSize     = 100
                computerName = $ComputerName # empty string value to ensure the URI is constructed correctly & query all computers
            }

            # Construct the URI
            $URI = Build-SEPMQueryURI -BaseURI $URI -QueryStrings $QueryStrings
    
            do {
                # Invoke the request params
                $params = @{
                    Method  = 'GET'
                    Uri     = $URI
                    headers = $headers
                }

                $resp = Invoke-ABRestMethod -params $params
                
                # Process the response
                $allResults += $resp.content

                # Increment the page index & update URI
                $QueryStrings.pageIndex++
                $URI = Build-SEPMQueryURI -BaseURI $URI -QueryStrings $QueryStrings
            } until ($resp.lastPage -eq $true)

            # Filtering
            if ($IncludeSubGroups) {
                $allResults = $allResults | Where-Object { $_.group.name -like "$GroupName*" }
            } else {
                $allResults = $allResults | Where-Object { $_.group.name -eq $GroupName }
            }

            # return the response
            return $allResults
        }

        # No parameters
        else {
            $allResults = @()
            $URI = $script:BaseURLv1 + "/computers"

            # URI query strings
            $QueryStrings = @{
                sort      = "COMPUTER_NAME"
                pageIndex = 1
                pageSize  = 100
            }

            # Construct the URI
            $URI = Build-SEPMQueryURI -BaseURI $URI -QueryStrings $QueryStrings
    
            do {
                # Invoke the request params
                $params = @{
                    Method  = 'GET'
                    Uri     = $URI
                    headers = $headers
                }

                $resp = Invoke-ABRestMethod -params $params

                # Process the response
                $allResults += $resp.content

                # Increment the page index & update URI
                $QueryStrings.pageIndex++
                $URI = Build-SEPMQueryURI -BaseURI $URI -QueryStrings $QueryStrings
            } until ($resp.lastPage -eq $true)

            # return the response
            return $allResults
        }
    }
}