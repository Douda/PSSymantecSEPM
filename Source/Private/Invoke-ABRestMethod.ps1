function Invoke-ABRestMethod {
    <#
    .SYNOPSIS
        Invokes a REST method with a PS version-appropriate method
    .DESCRIPTION
        Invokes a REST method with a PS version-appropriate method
        Handles the differences between PS versions 5 and 6 for certificate validation skipping
        Tests the certificate of the server if self signed
    .NOTES
        Helper function for Invoke-ABRestMethod
    .PARAMETER params
        A hashtable of parameters to pass to the Invoke-RestMethod cmdlet
    .EXAMPLE
        $params = @{
            Method  = 'POST'
            Uri     = $URI
            headers = $headers
        }
        Invoke-ABRestMethod -params $params
    #>
    
    
    param (
        # Hashtable of parameters
        [Parameter(
            Mandatory = $true
        )]
        [hashtable]
        $params
    )

    # If a Session object is provided, use its properties; otherwise fall back to script scope
    if ($params.ContainsKey('Session') -and $params.Session) {
        $effectiveSkipCert = $params.Session.SkipCert
        # Merge Session.Headers into $params.headers (Session.Headers as base)
        $mergedHeaders = @{} + $params.Session.Headers
        if ($params.ContainsKey('headers') -and $params.headers) {
            foreach ($key in $params.headers.Keys) {
                $mergedHeaders[$key] = $params.headers[$key]
            }
        }
        $params.headers = $mergedHeaders
    } else {
        $effectiveSkipCert = $script:SkipCert
    }

    switch ($PSVersionTable.PSVersion.Major) {
        { $_ -ge 6 } { 
            try {
                if ($effectiveSkipCert -eq $true) {
                    $resp = Invoke-RestMethod @params -SkipCertificateCheck
                } else {
                    $resp = Invoke-RestMethod @params
                }
            } catch {
                Write-Warning -Message "Error: $_"
                return "Error: $_"
            }
        }
        default {
            try {
                if ($effectiveSkipCert -eq $true) {
                    Skip-Cert
                    $resp = Invoke-RestMethod @params
                } else {
                    $resp = Invoke-RestMethod @params
                }
            } catch {
                Write-Warning -Message "Error: $_"
                return "Error: $_"
            }
        }
    }
    
    # return the response
    return $resp
}