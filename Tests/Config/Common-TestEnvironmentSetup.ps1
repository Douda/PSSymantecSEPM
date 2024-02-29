# Replace all files with mock files
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

# Load the test config in memory
$script:accessToken = Import-Clixml -Path $script:accessTokenFilePath
$script:Credential = Import-Clixml -Path $script:credentialsFilePath
$script:configuration = Import-Clixml -Path $script:configurationFilePath
$script:BaseURLv1 = "https://" + $script:configuration.ServerAddress + ":" + $script:configuration.port + "/sepm/api/v1"
$script:BaseURLv2 = "https://" + $script:configuration.ServerAddress + ":" + $script:configuration.port + "/sepm/api/v2"