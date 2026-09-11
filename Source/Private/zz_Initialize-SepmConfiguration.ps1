####################################
# Init script for the whole module #
####################################

## This is the initialization script for the module. The "zz_" prefix keeps it last in the
## alphabetically-ordered concatenation so all functions it calls are already defined.
## It lives in Private/ (not exported); its only import-time dependency is Import-SepmConfiguration,
## which sorts before it. It must NOT depend on Public functions — ModuleBuilder concatenates
## all Private files before all Public files.

# Update the data types when loading the module
Update-TypeData -PrependPath (Join-Path -Path $PSScriptRoot -ChildPath 'PSSymantecSEPM.Types.ps1xml')

# The credentials used to authenticate to the SEPM server.
[PSCredential]   $script:Credential = $null
[PSCustomObject] $script:accessToken = $null

# SEPM Server configuration
[string] $script:ServerAddress = $null
[string] $script:BaseURLv1 = $null
[string] $script:BaseURLv2 = $null
[bool] $script:SkipCert = $false # Needed for self-signed certificates

# Module name
[string] $script:ModuleName = "PSSymantecSEPM"

# The location of the file that we'll store any settings that can/should roam with the user.
[string] $script:configurationFilePath = [System.IO.Path]::Combine(
    [System.Environment]::GetFolderPath('ApplicationData'),
    'PSSymantecSEPM',
    'config.json')

# The location of the file that we'll store credentials
[string] $script:credentialsFilePath = [System.IO.Path]::Combine(
    [System.Environment]::GetFolderPath('ApplicationData'),
    'PSSymantecSEPM',
    'creds.xml')

# The location of the file that we'll store the Access Token SecureString
# which cannot/should not roam with the user.
[string] $script:accessTokenFilePath = [System.IO.Path]::Combine(
    [System.Environment]::GetFolderPath('LocalApplicationData'),
    'PSSymantecSEPM',
    'accessToken.xml')

# The session-cached copy of the module's configuration properties
[PSCustomObject] $script:configuration = $null

function Initialize-SepmConfiguration {
    <#
    .SYNOPSIS
        Populates the configuration of the module for this session, loading in any values
        that may have been saved to disk.

    .DESCRIPTION
        Populates the configuration of the module for this session, loading in any values
        that may have been saved to disk.

    .NOTES
        Internal helper method.  This is actually invoked at the END of this file.
    #>
    [CmdletBinding()]
    param()

    # Load in the configuration from disk
    $script:configuration = Import-SepmConfiguration -Path $script:configurationFilePath
    if ($script:configuration.ServerAddress -and $script:configuration.port) {
        $script:BaseURLv1 = "https://" + $script:configuration.ServerAddress + ":" + $script:configuration.port + "/sepm/api/v1"
        $script:BaseURLv2 = "https://" + $script:configuration.ServerAddress + ":" + $script:configuration.port + "/sepm/api/v2"
    }
    # No config on disk (or incomplete): script variables keep the defaults set at the top of
    # this file. We deliberately do NOT call Reset-SEPMConfiguration here — that cmdlet deletes
    # the user's config file, and an import must not have filesystem side effects (it also
    # would force this file to stay in Public/, since it loads last).

    # Load in the credentials from disk
    if (Test-Path $script:credentialsFilePath) {
        try {
            $script:Credential = Import-Clixml -Path $script:credentialsFilePath
        } catch {
            Write-Verbose "No credentials found from '$script:credentialsFilePath': $_"
        }
    }

    # Load in the access token from disk
    if (Test-Path $script:accessTokenFilePath) {
        try {
            $script:accessToken = Import-Clixml -Path $script:accessTokenFilePath
        } catch {
            Write-Verbose "Failed to import access token from '$script:accessTokenFilePath': $_"
        }
    }
    
}

# Invoke the initialization method to populate the configuration
Initialize-SepmConfiguration