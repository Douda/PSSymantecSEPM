function Send-SEPMCommandClearIronCache {
    <# # TODO update help
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
    .PARAMETER SHA256
        SHA256 hash of the suspicious file.
        Cannot be used with MD5 or SHA1
    .PARAMETER MD5
        MD5 hash of the suspicious file.
        Cannot be used with SHA256 or SHA1
    .PARAMETER SHA1
        SHA1 hash of the suspicious file.
        Cannot be used with SHA256 or MD5
    .PARAMETER SkipCertificateCheck
        Skip certificate check
    .EXAMPLE
        Send-SEPMCommandClearIronCache -ComputerName "Computer1"
        Sends a command to quarantine Computer1
    .EXAMPLE
        "Computer1", "Computer2" | Send-SEPMCommandClearIronCache
        Sends a command to quarantine Computer1 and Computer2
    .EXAMPLE
        Send-SEPMCommandClearIronCache -GroupName "My Company\EMEA\Workstations\Site1"
        Sends a command to quarantine all computers in "My Company\EMEA\Workstations\Site1"
        Does not include subgroups
    #>
    
    #TODO finish function
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

        # SHA256 hash of the suspicious file.
        [Parameter(ParameterSetName = 'SHA256Hash')]
        [Parameter(ParameterSetName = 'ComputerName')]
        [ValidateScript({
                if ($_.Length -ne 64) { throw "SHA256 hash must be 64 characters long" }
                return $true
            })]
        [string]
        $SHA256,

        # MD5 hash of the suspicious file.
        [Parameter(ParameterSetName = 'MD5Hash')]
        [Parameter(ParameterSetName = 'ComputerName')]
        [ValidateScript({
                if ($_.Length -ne 32) { throw "MD5 hash must be 32 characters long" }
                return $true
            })]
        [string]
        $MD5,

        # SHA1 hash of the suspicious file.
        [Parameter(ParameterSetName = 'SHA1Hash')]
        [Parameter(ParameterSetName = 'ComputerName')]
        [ValidateScript({
                if ($_.Length -ne 40) { throw "SHA1 hash must be 40 characters long" }
                return $true
            })]
        [string]
        $SHA1,

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
        $URI = $script:BaseURLv1 + "/command-queue/ironcache"

        # Build body and add correct hash to body
        $body = @{
            data = @()
        }
        $hashParameter = $PSCmdlet.MyInvocation.BoundParameters.Keys | Where-Object { $_ -in @('SHA256', 'MD5', 'SHA1') }
        switch ($hashParameter) {
            'SHA256' {
                $body.Add("hashType", "sha256")
                $body.data += $SHA256
            }
            'MD5' {
                $body.Add("hashType", "md5")
                $body.data += $MD5
            }
            'SHA1' {
                $body.Add("hashType", "sha1")
                $body.data += $SHA1
            }
        }

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
            # Get group ID from group name
            $GroupID = Get-SEPMGroups | Where-Object { $_.fullPathName -eq $GroupName } | Select-Object -ExpandProperty id -First 1

            # URI query strings
            $QueryStrings = @{
                group_ids = $GroupID
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