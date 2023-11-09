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

    .EXAMPLE
        Set-SEPMAuthentication

        Prompts the user for credentials and SEPM server address

    .EXAMPLE
        $secureString = ("<Your Access Token>" | ConvertTo-SecureString -AsPlainText -Force)
        $cred = New-Object System.Management.Automation.PSCredential "username", $secureString
        Set-SEPMAuthentication -Credential $cred

        Allows you to specify your username and password as a PSCredential object

    .EXAMPLE
        Set-SEPMAuthentication -credential (Get-Credential)

        Prompts the user for username and password, saves them to disk and in the PS Session

    .EXAMPLE
        $creds = Get-Credential
        Set-SEPMAuthentication -Credential $cred -ServerAddress "SEPMSRV01"

    .EXAMPLE
        Set-SEPMAuthentication -Port 8888

        Changes the API communication port to 8888. Default is 8446.
#>
    [CmdletBinding()]
    param(
        [string] $ServerAddress,

        [int] $Port = 8446,
        
        [PSCredential] $Creds
    )

    switch ($PSBoundParameters.Keys) {
        'Creds' {
            if ([String]::IsNullOrWhiteSpace($Creds.GetNetworkCredential().Password)) {
                $message = "Password not provided.  Provide correct credentials and try again."
                Write-Error -Message $message
                throw $message
            }

            # Setting script scope variables so that they can be used in other functions
            $script:Credential = $Creds

            # Saving credentials to disk
            $Creds | Export-Clixml -Path $script:credentialsFilePath -Force
        }
        'ServerAddress' {
            Set-SepmConfiguration -ServerAddress $ServerAddress
        }
        'Port' {
            Set-SepmConfiguration -Port $Port
        }
    }
}