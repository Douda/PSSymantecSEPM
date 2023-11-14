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

    # Test the certificate if self signed
    if (-not $script:SkipCert) {
        Test-SEPMCertificate -URI $params.Uri
    }

    switch ($PSVersionTable.PSVersion.Major) {
        { $_ -ge 6 } { 
            try {
                if ($script:SkipCert -eq $true) {
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
                if ($script:SkipCert -eq $true) {
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