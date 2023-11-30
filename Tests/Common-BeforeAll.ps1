# The path to a file storing the contents of the user's config file before tests got underway
$script:originalConfigFile = $null
$script:originalCredentialsFile = $null
$script:originalAccessTokenFile = $null

function Initialize-CommonTestSetup {
    param ()
    
    # Backup the user's configuration file before testing
    $script:originalConfigFile = New-TemporaryFile
    Backup-SepmConfiguration -Path $script:originalConfigFile

    #Backup the user's credentials file before testing
    $script:originalCredentialsFile = New-TemporaryFile
    Backup-SepmAuthentication -Path $script:originalCredentialsFile -Credential -Force

    # Backup the user's access token file before testing
    $script:originalAccessTokenFile = New-TemporaryFile
    Backup-SepmAuthentication -Path $script:originalAccessTokenFile -AccessToken -Force

    # Reset configuration
    Reset-SEPMConfiguration
    Clear-SEPMAuthentication

}

Initialize-CommonTestSetup