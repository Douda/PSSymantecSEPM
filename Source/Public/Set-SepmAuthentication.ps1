function Set-SEPMAuthentication {
    <#
    .SYNOPSIS
        Allows the user to configure the SEPM Authentication

    .DESCRIPTION
        Allows the user to configure the SEPM Authentication

        Username and password will be securely stored on the machine for use in all future PowerShell sessions.

    .PARAMETER Credentials
        A PSCredential object containing the username and password to use for authentication

    .EXAMPLE
        Set-SEPMAuthentication Credentials (Get-Credential)

        Prompts the user for username and password, saves them to disk and in the PS Session

    .EXAMPLE
        $Credentials = Get-Credential
        Set-SEPMAuthentication -Credential $cred
#>
    [CmdletBinding()]
    param(
        [PSCredential] $Credentials
    )

    # If no credentials are provided, prompt the user for them
    if ($null -eq $Credentials) {
        $Credentials = Get-Credential
    }

    # If the user provides a username and password, verify if password is not null or empty
    if ([String]::IsNullOrWhiteSpace($Credentials.GetNetworkCredential().Password)) {
        $message = "Password not provided.  Provide correct credentials and try again."
        Write-Error -Message $message
        throw $message
    }

    # Setting script scope variable so that credentials can be used in other functions
    $script:Credential = $Credentials

    # Test if the credential path exists
    if (-not (Test-Path -Path $script:credentialsFilePath)) {
        New-Item -Path $script:credentialsFilePath -ItemType File -Force | Out-Null
    }

    # Saving credentials to disk
    $Credentials | Export-Clixml -Path $script:credentialsFilePath -Force
        
}