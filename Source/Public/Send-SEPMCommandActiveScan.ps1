function Send-SEPMCommandActiveScan {
    <#
.SYNOPSIS
    Send an active scan command to SEP endpoints
.DESCRIPTION
    Send an active scan command to SEP endpoints
    This will scan the specified computer(s) or group(s) for threats
.PARAMETER ComputerName
    The name of the computer to send the command to
    Cannot be used with GroupName
.PARAMETER GroupName
    The name of the group to send the command to
    Cannot be used with ComputerName
    Does not include subgroups
.PARAMETER SkipCertificateCheck
    Skip certificate check
.EXAMPLE
    Send-SEPMCommandActiveScan -ComputerName "Computer1"
 
    Sends an active scan command to Computer1
.EXAMPLE
    "Computer1", "Computer2" | Send-SEPMCommandActiveScan
 
    Sends an active scan command to Computer1 and Computer2
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
        # Init 
        $URI = $script:BaseURLv1 + "/command-queue/activescan"

        if ($ComputerName) {
            # Get computer ID(s) from computer name(s)
            $ComputerIDList = @()
            foreach ($C in $ComputerName) {
                $ComputerID = Get-SEPComputers -ComputerName $C | Select-Object -ExpandProperty uniqueId
                $ComputerIDList += $ComputerID
            }

            # URI query strings
            $QueryStrings = @{
                computer_ids = $ComputerIDList
            }

            # Construct the URI
            $builder = New-Object System.UriBuilder($URI)
            $query = [System.Web.HttpUtility]::ParseQueryString($builder.Query)
            foreach ($param in $QueryStrings.GetEnumerator()) {
                $query[$param.Key] = $param.Value
            }
            $builder.Query = $query.ToString()
            $URI = $builder.ToString()
        }

        # If group name is specified
        elseif ($GroupName) {
            # Get group ID(s) from group name(s)
            $GroupIDList = @()
            foreach ($G in $GroupName) {
                $GroupID = Get-SEPMGroups | Where-Object { $_.fullPathName -eq $G } | Select-Object -ExpandProperty id -First 1
                $GroupIDList += $GroupID
            }

            # URI query strings
            $QueryStrings = @{
                group_ids = $GroupIDList
            }

            # Construct the URI
            $builder = New-Object System.UriBuilder($URI)
            $query = [System.Web.HttpUtility]::ParseQueryString($builder.Query)
            foreach ($param in $QueryStrings.GetEnumerator()) {
                $query[$param.Key] = $param.Value
            }
            $builder.Query = $query.ToString()
            $URI = $builder.ToString()
        }

        # Invoke the request params
        $params = @{
            Method      = 'POST'
            Uri         = $URI
            headers     = $headers
            Body        = $body | ConvertTo-Json
            ContentType = 'application/json'
        }
        
        $resp = Invoke-ABRestMethod -params $params

        # return the response
        return $resp
    }
}