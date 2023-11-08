function Test-CertificateSelfSigned {
    <#
    .SYNOPSIS
        This function tests a webserver to see if it is using a self-signed certificate
    .DESCRIPTION
        This function tests a webserver to see if it is using a self-signed certificate
        If so, sets the SkipCert variable to $true to continue with the connection
    .PARAMETER URI
        The URI of the webserver to test
    .INPUTS
        System.String
    .OUTPUTS
        None
    .EXAMPLE
        Test-CertificateSelfSigned -URI https://www.example.com

        Tests the webserver at https://www.example.com to see if it is using a self-signed certificate
    #>
    
    [CmdletBinding()]
    param (
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [string]
        $URI
    )
    
    try {
        Invoke-WebRequest $URI
    } catch {
        $message = "SSL Certificate test failed.  The certificate for $URI is self-signed."
        Write-Error -Message $message

        $Response = Read-Host -Prompt 'Press enter to ignore this and continue without SSL/TLS secure channel'
        if ($Response -eq "") {
            if ($PSVersionTable.PSVersion.Major -lt 6) {
                Skip-Cert
            }
            $script:SkipCert = $true
        }
    }
}