
function Complete-CommonTestSetup {
    param ()

    # Restore original configuration / credentials file locations
    $script:configurationFilePath = $script:originalConfigFilePath
    $script:credentialsFilePath = $script:originalCredentialsFilePath
    $script:accessTokenFilePath = $script:originalAccessTokenFilePath

    # Restore all configuration / authentication files after testing
    # Delete the temp files that we used to store the user's original configuration files
    Restore-SEPMConfiguration -Path $script:originalConfigFile
    Remove-Item -Path $script:originalConfigFile
    $script:originalConfigFile = $null

    Restore-SEPMAuthentication -Path $script:originalCredentialsFile -Credential
    Remove-Item -Path $script:originalCredentialsFile
    $script:originalCredentialsFile = $null

    Restore-SEPMAuthentication -Path $script:originalAccessTokenFile -AccessToken
    Remove-Item -Path $script:originalAccessTokenFile
    $script:originalAccessTokenFile = $null
}

Complete-CommonTestSetup