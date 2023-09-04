function Get-SEPComputers {
    <#
    .SYNOPSIS
        Gets the information about the computers in a specified domain
    .DESCRIPTION
        Gets the information about the computers in a specified domain. A system administrator account is required for this REST API.
    .EXAMPLE
        Get-SEPComputers

        Gets computer details for all computers in the domain
    .EXAMPLE
        Get-SEPComputers -ComputerName "ComputerName"

        Gets computer details for the specified computer ComputerName
    .EXAMPLE
        "MyComputer" | Get-SEPComputers

        Gets computer details for the specified computer MyComputer
#>
    [CmdletBinding()]
    Param (
        # ComputerName
        [Parameter(
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [Alias("Hostname", "DeviceName", "Device", "Computer")]
        [String]
        $ComputerName
    )

    begin {
        # initialize the configuration
        $test_token = Test-SEPMAccessToken
        if ($test_token -eq $false) {
            Get-SEPMAccessToken | Out-Null
        }
        $URI = $script:BaseURLv1 + "/computers"
        $headers = @{
            "Authorization" = "Bearer " + $script:accessToken.token
            "Content"       = 'application/json'
        }
    }

    process {
        $allResults = @()

        if (-not $ComputerName) {
            $ComputerName = ""
        }

        # URI query strings
        $QueryStrings = @{
            sort         = "COMPUTER_NAME"
            pageIndex    = 1
            pageSize     = 100
            computerName = $ComputerName
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
        do {
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
                
                # Process the response
                $allResults += $resp.content

                # Increment the page index & update URI
                $QueryStrings.pageIndex++
                $query = [System.Web.HttpUtility]::ParseQueryString($builder.Query)
                foreach ($param in $QueryStrings.GetEnumerator()) {
                    $query[$param.Key] = $param.Value
                }
                $builder.Query = $query.ToString()
                $URI = $builder.ToString()
            } catch {
                Write-Warning -Message "Error: $_"
            }
        } until ($resp.lastPage -eq $true)

        # return the response
        return $allResults
    }
}