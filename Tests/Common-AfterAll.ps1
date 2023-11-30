
function Complete-CommonTestSetup {
    param ()

    # Restore all configuration / authentication files after testing
    
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