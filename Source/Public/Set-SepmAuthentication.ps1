function Set-SepmAuthentication {
    <#
    .SYNOPSIS
        Allows the user to configure the API token that should be used for authentication
        with the GitHub API.

    .DESCRIPTION
        Allows the user to configure the API token that should be used for authentication
        with the GitHub API.

        The token will be stored on the machine as a SecureString and will automatically
        be read on future PowerShell sessions with this module.  If the user ever wishes
        to remove their authentication from the system, they simply need to call
        Clear-SepmAuthentication.

        The Git repo for this module can be found here: http://aka.ms/PowerShellForGitHub

    .PARAMETER Credential
        If provided, instead of prompting the user for their API Token, it will be extracted
        from the password field of this credential object.

    .PARAMETER SessionOnly
        By default, this method will store the provided API Token as a SecureString in a local
        file so that it can be restored automatically in future PowerShell sessions.  If this
        switch is provided, the file will not be created/updated and the authentication information
        will only remain in memory for the duration of this PowerShell session.

    .EXAMPLE
        Set-SepmAuthentication

        Prompts the user for their GitHub API Token and stores it in a file on the machine as a
        SecureString for use in future PowerShell sessions.

    .EXAMPLE
        $secureString = ("<Your Access Token>" | ConvertTo-SecureString -AsPlainText -Force)
        $cred = New-Object System.Management.Automation.PSCredential "username is ignored", $secureString
        Set-SepmAuthentication -Credential $cred
        $secureString = $null # clear this out now that it's no longer needed
        $cred = $null # clear this out now that it's no longer needed

        Allows you to specify your access token as a plain-text string ("<Your Access Token>")
        which will be securely stored on the machine for use in all future PowerShell sessions.

    .EXAMPLE
        Set-SepmAuthentication -SessionOnly

        Prompts the user for their GitHub API Token, but keeps it in memory only for the duration
        of this PowerShell session.

    .EXAMPLE
        Set-SepmAuthentication -Credential $cred -SessionOnly

        Uses the API token stored in the password field of the provided credential object for
        authentication, but keeps it in memory only for the duration of this PowerShell session..
#>
    [CmdletBinding(SupportsShouldProcess)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUsePSCredentialType", "", Justification = "The System.Management.Automation.Credential() attribute does not appear to work in PowerShell v4 which we need to support.")]
    param(
        [string] $ServerAddress,
        
        [PSCredential] $Creds,

        [switch] $SessionOnly
    )

    if (-not $PSCmdlet.ShouldProcess('Sepm Authentication', 'Set')) {
        return
    }

    if (-not $PSBoundParameters.ContainsKey('Credential')) {
        $message = 'Please provide your Username and Password.'
        if (-not $SessionOnly) {
            $message = $message + '  ***The token is being cached across PowerShell sessions.  To clear caching, call Clear-SepmAuthentication.***'
        }

        $Creds = Get-Credential -Message $message
    }

    if ([String]::IsNullOrWhiteSpace($Creds.GetNetworkCredential().Password)) {
        $message = "Password not provided.  Nothing to do."
        Write-Log -Message $message -Level Error
        throw $message
    }

    $script:Credential = $Creds

    if (-not $PSBoundParameters.ContainsKey('ServerAddress')) {
        $message = 'Please provide your ServerAddress.'
        if (-not $SessionOnly) {
            $message = $message + '  ***The token is being cached across PowerShell sessions.  To clear caching, call Clear-SepmAuthentication.***'
        }

        $ServerAddress = Read-Host -Prompt "ServerAddress"
    }


    if (-not $SessionOnly) {
        Set-SepmConfiguration -Username $Creds.UserName
        Set-SepmConfiguration -Password $Creds.GetNetworkCredential().SecurePassword
        Set-SepmConfiguration -ServerAddress $ServerAddress
    }
}