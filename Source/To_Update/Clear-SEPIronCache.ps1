function Clear-SEPIronCache {
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
    .EXAMPLE
        Clear-SEPIronCache -ComputerName "Computer1"
        Sends a command to quarantine Computer1
    .EXAMPLE
        "Computer1", "Computer2" | Clear-SEPIronCache
        Sends a command to quarantine Computer1 and Computer2
    .EXAMPLE
        Clear-SEPIronCache -GroupName "My Company\EMEA\Workstations\Site1"
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
        $SHA1
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

            $URI = $script:BaseURLv1 + "/command-queue/ironcache"

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

            # Building body and add correct hash to body
            # TODO verify this works
            $body = @{
                FingerPrintListPayload = @{
                    data = @()
                }
            }
            $hashParameter = $PSCmdlet.MyInvocation.BoundParameters.Keys | Where-Object { $_ -in @('SHA256', 'MD5', 'SHA1') }
            switch ($hashParameter) {
                'SHA256' {
                    $body.FingerPrintListPayload.Add("hashType", "sha256")
                    $body.FingerPrintListPayload.data += $SHA256
                }
                'MD5' {
                    $body.FingerPrintListPayload.Add("hashType", "md5")
                    $body.FingerPrintListPayload.data += $MD5
                }
                'SHA1' {
                    $body.FingerPrintListPayload.Add("hashType", "sha1")
                    $body.FingerPrintListPayload.data += $SHA1
                }
            }

            # Invoke the request
            # If the version of PowerShell is 6 or greater, then we can use the -SkipCertificateCheck parameter
            # else we need to use the Skip-Cert function if self-signed certs are being used.
            try {
                # Invoke the request params
                $params = @{
                    Method      = 'POST'
                    Uri         = $URI
                    headers     = $headers
                    Body        = $body | ConvertTo-Json
                    ContentType = 'application/json'
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
            $URI = $script:BaseURLv1 + "/command-queue/ironcache"

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
    
            # Invoke the request
            # If the version of PowerShell is 6 or greater, then we can use the -SkipCertificateCheck parameter
            # else we need to use the Skip-Cert function if self-signed certs are being used.
            try {
                # Invoke the request params
                $params = @{
                    Method      = 'POST'
                    Uri         = $URI
                    headers     = $headers
                    ContentType = 'application/json'
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