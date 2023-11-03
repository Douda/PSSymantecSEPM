function Block-SEPClient {
    <#
    .SYNOPSIS
        Send a quarantine/unquarantine command to SEP endpoints
    .DESCRIPTION
        Send a quarantine/unquarantine command to SEP endpoints
    .PARAMETER ComputerName
        The name of the computer to send the command to
        Cannot be used with GroupName
    .PARAMETER GroupName
        The name of the group to send the command to
        Cannot be used with ComputerName
        Does not include subgroups
    .PARAMETER Unquarantine
        Switch parameter to unquarantine the SEP client
    .EXAMPLE
        Block-SEPClient -ComputerName "Computer1"
        Sends a command to quarantine Computer1
    .EXAMPLE
        "Computer1", "Computer2" | Block-SEPClient
        Sends a command to quarantine Computer1 and Computer2
    .EXAMPLE
        Block-SEPClient -GroupName "My Company\EMEA\Workstations\Site1"
        Sends a command to quarantine all computers in "My Company\EMEA\Workstations\Site1"
        Does not include subgroups
    #>
    
    
    [CmdletBinding()]
    param (
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

        # Unquarantine
        [Parameter()]
        [switch]
        $Unquarantine
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
        if ($ComputerName) {
            # Get computer ID(s) from computer name(s)
            $ComputerIDList = @()
            foreach ($C in $ComputerName) {
                $ComputerID = Get-SEPComputers -ComputerName $C | Select-Object -ExpandProperty uniqueId
                $ComputerIDList += $ComputerID
            }

            $URI = $script:BaseURLv1 + "/command-queue/quarantine"

            # URI query strings
            $QueryStrings = @{
                computer_ids = $ComputerIDList
            }

            # Add unquarantine if specified
            if ($Unquarantine) {
                $QueryStrings['undo'] = $true
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
                    Method  = 'POST'
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

            # return the response
            return $resp
        }

        # If group name is specified
        elseif ($GroupName) {
            # Get group ID from group name
            $GroupID = Get-SEPMGroups | Where-Object { $_.fullPathName -eq $GroupName } | Select-Object -ExpandProperty id -First 1
            $URI = $script:BaseURLv1 + "/command-queue/quarantine"

            # URI query strings
            $QueryStrings = @{
                group_ids = $GroupID
            }

            # Add unquarantine if specified
            if ($Unquarantine) {
                $QueryStrings['undo'] = $true
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
                    Method  = 'POST'
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

            # return the response
            return $resp
        }
    }
}