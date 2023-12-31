    function Skip-Cert {
        <#
    .SYNOPSIS
        This function allows skipping the SSL/TLS Secure channel check in the event that there is not a valid certificate available
    .DESCRIPTION
        This function allows skipping the SSL/TLS Secure channel check in the event that there is not a valid certificate available
    .NOTES
        Required for self-signed certificates skipping with Windows Powershell 5.1 and below
        This function is used internally by the module and should not be called directly
    .PARAMETER
    None
    .EXAMPLE
        Skip-Cert
    .OUTPUTS
        None
    #>
        if (-not ([System.Management.Automation.PSTypeName]'ServerCertificateValidationCallback').Type) {
            $certCallback = @"
        using System;
        using System.Net;
        using System.Net.Security;
        using System.Security.Cryptography.X509Certificates;
        public class ServerCertificateValidationCallback
        {
            public static void Ignore()
            {
                if(ServicePointManager.ServerCertificateValidationCallback ==null)
                {
                    ServicePointManager.ServerCertificateValidationCallback +=
                        delegate
                        (
                            Object obj,
                            X509Certificate certificate,
                            X509Chain chain,
                            SslPolicyErrors errors
                        )
                        {
                            return true;
                        };
                }
            }
        }
"@
            Add-Type $certCallback
        }
        [ServerCertificateValidationCallback]::Ignore()
    }