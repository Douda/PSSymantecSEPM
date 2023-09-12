Describe "Skip-Cert function" {
    Context "When the function is called" {
        It "should not throw an error" {
            { Skip-Cert } | Should Not Throw
        }
        It "should add the ServerCertificateValidationCallback class" {
            Skip-Cert
            $callbackClass = Get-Type ServerCertificateValidationCallback
            $callbackClass | Should Not BeNullOrEmpty
        }
        It "should set the ServerCertificateValidationCallback to always return true" {
            Skip-Cert
            $callback = [System.Net.ServicePointManager]::ServerCertificateValidationCallback
            $callback.Invoke($null, [System.Security.Cryptography.X509Certificates.X509Certificate], [System.Security.Cryptography.X509Certificates.X509Chain], [System.Net.Security.SslPolicyErrors]) | Should Be $true
        }
    }
}