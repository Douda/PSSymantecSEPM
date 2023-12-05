# The path to a file storing the contents of the user's config file before tests got underway
$script:originalConfigFile = $null
$script:originalCredentialsFile = $null
$script:originalAccessTokenFile = $null

function Initialize-CommonTestSetup {
    param ()
    
    # Backup the user's configuration file before testing
    $script:originalConfigFile = New-TemporaryFile
    Backup-SepmConfiguration -Path $script:originalConfigFile

    # Backup the user's credentials file before testing
    $script:originalCredentialsFile = New-TemporaryFile
    Backup-SepmAuthentication -Path $script:originalCredentialsFile -Credential -Force

    # Backup the user's access token file before testing
    $script:originalAccessTokenFile = New-TemporaryFile
    Backup-SepmAuthentication -Path $script:originalAccessTokenFile -AccessToken -Force

    # Backup original configuration / credentials file locations
    $script:originalConfigFilePath = $script:configurationFilePath
    $script:originalCredentialsFilePath = $script:credentialsFilePath
    $script:originalAccessTokenFilePath = $script:accessTokenFilePath

    # Reset configuration
    Clear-SEPMAuthentication
    Reset-SEPMConfiguration

    # Replace all config files with mock files
    $script:configurationFilePath = Join-Path -Path 'TestDrive:' -ChildPath 'config.xml'
    $script:credentialsFilePath = Join-Path -Path 'TestDrive:' -ChildPath 'creds.xml'
    $script:accessTokenFilePath = Join-Path -Path 'TestDrive:' -ChildPath 'token.xml'

    # Configuration file content
    [PSCustomObject]@{
        'ServerAddress' = 'FakeServer01'
        'port'          = '1234'
        'domain'        = ''
    } | Export-Clixml -Path $script:configurationFilePath -Force

    # Credential file content | Fakeuser / FakePassword
    $creds = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'FakeUser', (ConvertTo-SecureString -String 'FakePassword' -AsPlainText -Force)
    $creds | Export-Clixml -Path $script:credentialsFilePath -Force

    # Token file content
    [PSCustomObject]@{
        'token'              = 'FakeToken'
        tokenExpiration      = (Get-Date).AddSeconds(3600)
        SkipCertificateCheck = $true
    } | Export-Clixml -Path $script:accessTokenFilePath -Force
            


}

Initialize-CommonTestSetup