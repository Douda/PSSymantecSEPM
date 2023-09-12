function Set-SEPMAuthentication {
    <#
    .SYNOPSIS
        Allows the user to configure the SEPM Authentication

    .DESCRIPTION
        Allows the user to configure the SEPM Authentication

        Username and password will be securely stored on the machine for use in all future PowerShell sessions.

    .PARAMETER Credential
        If provided, instead of prompting the user for their API Token, it will be extracted
        from the password field of this credential object.

    .PARAMETER SessionOnly
        By default, this method will store the provided API Token as a SecureString in a local
        file so that it can be restored automatically in future PowerShell sessions.  If this
        switch is provided, the file will not be created/updated and the authentication information
        will only remain in memory for the duration of this PowerShell session.

    .EXAMPLE
        Set-SEPMAuthentication

        Prompts the user for credentials and SEPM server address

    .EXAMPLE
        $secureString = ("<Your Access Token>" | ConvertTo-SecureString -AsPlainText -Force)
        $cred = New-Object System.Management.Automation.PSCredential "username", $secureString
        Set-SEPMAuthentication -Credential $cred

        Allows you to specify your username and password as a PSCredential object

    .EXAMPLE
        Get-Credential | Set-SEPMAuthentication

        Prompts the user for username and password and pipes the resulting credential object

    .EXAMPLE
        Set-SEPMAuthentication -Credential $cred -ServerAddress "SEPMSRV01"

    .EXAMPLE
        Set-SEPMAuthentication -Port 8888

        Changes the API communication port to 8888. Default is 8446.
#>
    [CmdletBinding(SupportsShouldProcess)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUsePSCredentialType", "", Justification = "The System.Management.Automation.Credential() attribute does not appear to work in PowerShell v4 which we need to support.")]
    param(
        [string] $ServerAddress,

        [int] $Port = 8446,
        
        [PSCredential] $Creds
    )

    if (-not $PSCmdlet.ShouldProcess('Sepm Authentication', 'Set')) {
        return
    }

    if (-not $PSBoundParameters.ContainsKey('Creds')) {
        $message = 'Please provide your Username and Password'
        $Creds = Get-Credential -Message $message
    }

    if ([String]::IsNullOrWhiteSpace($Creds.GetNetworkCredential().Password)) {
        $message = "Password not provided.  Nothing to do."
        Write-Error -Message $message
        throw $message
    }

    # Setting script scope variables so that they can be used in other functions
    $script:Credential = $Creds

    if (-not $PSBoundParameters.ContainsKey('ServerAddress')) {
        $message = 'Please provide your ServerAddress.'
        $ServerAddress = Read-Host -Prompt "SEPM Server address"
    }

    # verify if the the $port is not the default one
    if ($Port -ne 8446) {
        $message = 'Please provide SEPM API Service port (Default 8446)'
        $Port = Read-Host -Prompt "SEPM API Service port"
    }

    Set-SepmConfiguration -ServerAddress $ServerAddress
    Set-SepmConfiguration -Port $Port
    $Creds | Export-Clixml -Path $script:credentialsFilePath -Force

}