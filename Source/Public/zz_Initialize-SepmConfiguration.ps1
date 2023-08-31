####################################
# Init script for the whole module #
####################################

## This is the initialization script for the module.  It is invoked at the end of the module's
## prefix file as "zz_" to load this module at last.  This is done to ensure that all other functions are first loaded
## This function should be private but will stay Public for the moment as it needs to be the last function to be loaded in the module
## TODO make this function private

# The credentials used to authenticate to the SEPM server.
[PSCredential]   $script:Credential = $null
[PSCustomObject] $script:accessToken = $null

# SEPM Server configuration
[string] $script:ServerAddress = $null
[string] $script:BaseURL = $null
[bool] $script:SkipCert = $false

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

# Only tell users about needing to configure an API token once per session.
#TODO make use of the boolean
$script:seenTokenWarningThisSession = $false

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

    $script:seenTokenWarningThisSession = $false
    $script:configuration = Import-SepmConfiguration -Path $script:configurationFilePath
    if ($script:configuration) {
        $script:BaseURL = "https://" + $script:configuration.ServerAddress + ":" + $script:configuration.port + "/sepm/api/v1"
    }
    if (Test-Path $script:credentialsFilePath) {
        $script:Credential = Import-Clixml -Path $script:credentialsFilePath -ErrorAction SilentlyContinue
    }
    if (Test-Path $script:accessTokenFilePath) {
        $script:accessToken = Import-Clixml -Path $script:accessTokenFilePath -ErrorAction SilentlyContinue
    }
    
}

# Invoke the initialization method to populate the configuration
Initialize-SepmConfiguration