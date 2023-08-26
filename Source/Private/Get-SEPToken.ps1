Function Get-SEPToken {
    <#
    .SYNOPSIS
    Generates a token that is used for the Symantec Console authentication process
    This requires the username, password (and domain if used).
    
    .DESCRIPTION
    Long description
    
    .EXAMPLE
    Get-SEPToken
    #>


    if ($null -eq $BaseURL) {
        "Please enter your symantec server's name and port."
        "(e.g. <sepservername>:8446)"
        $ServerAddress = Read-Host -Prompt "Value"
        $Global:BaseURL = "https://" + $ServerAddress + '/sepm/api/v1'
    }
    $Creds = Get-Credential
    $body = @{
        "username" = $Creds.UserName
        "password" = ([System.Net.NetworkCredential]::new("", $Creds.Password).Password)
        "domain"   = ""
    }

    if ($null -ne $body) {
        $URI = $BaseURL + '/identity/authenticate'
        try {
            Invoke-WebRequest $BaseURL
        } catch {
            'SSL Certificate test failed, skipping certificate validation. Please check your certificate settings and verify this is a legitimate source.'
            $Response = Read-Host -Prompt 'Please press enter to ignore this and continue without SSL/TLS secure channel'
            if ($Response -eq "") {
                if ($PSVersionTable.PSVersion.Major -lt 6) {
                    Skip-Cert
                }
                if ($PSVersionTable.PSVersion.Major -ge 6) {
                    $Global:SkipCert = $true
                }
            }
        }
        try {
            if ($PSVersionTable.PSVersion.Major -lt 6) {
                $SEPToken = (Invoke-RestMethod -Method POST -Uri $URI -ContentType "application/json" -Body ($body | ConvertTo-Json)).token
            }
            if ($PSVersionTable.PSVersion.Major -ge 6) {
                if ($Global:SkipCert -eq $true) {
                    $SEPToken = (Invoke-RestMethod -Method POST -Uri $URI -ContentType "application/json" -Body ($body | ConvertTo-Json) -SkipCertificateCheck).token
                } else {
                    $SEPToken = (Invoke-RestMethod -Method POST -Uri $URI -ContentType "application/json" -Body ($body | ConvertTo-Json) -SkipCertificateCheck).token
                }
            }
        } catch {
            Get-RestErrorDetails
        }
    }
    $global:headers = @{
        "Authorization" = "Bearer $SEPToken"
        "Content"       = 'application/json'
    }
}