[CmdletBinding()]
param()

# Build & Load the module
$moduleRootPath = Split-Path -Path $PSScriptRoot -Parent
. (Join-Path -Path $moduleRootPath -ChildPath 'Tests/Config/Common-Init.ps1')

Describe 'Initialize-SEPMSession' {
    InModuleScope PSSymantecSEPM {
        BeforeAll {
            # Common backups (these are functions, unaffected by $script: scoping)
            $moduleRootPath = Split-Path -Path $PSScriptRoot -Parent
            . (Join-Path -Path $moduleRootPath -ChildPath 'Tests/Config/Common-BeforeAll.ps1')
        }

        AfterAll {
            $moduleRootPath = Split-Path -Path $PSScriptRoot -Parent
            . (Join-Path -Path $moduleRootPath -ChildPath 'Tests/Config/Common-AfterAll.ps1')
        }

        # Shared helper: sets up module-scoped state with config, creds, token on TestDrive:
        function Setup-TestModuleState {
            $script:configurationFilePath = Join-Path -Path 'TestDrive:' -ChildPath 'config.xml'
            $script:credentialsFilePath = Join-Path -Path 'TestDrive:' -ChildPath 'creds.xml'
            $script:accessTokenFilePath = Join-Path -Path 'TestDrive:' -ChildPath 'token.xml'

            [PSCustomObject]@{
                'ServerAddress' = 'FakeServer01'
                'port'          = '1234'
                'domain'        = ''
            } | Export-Clixml -Path $script:configurationFilePath -Force

            $creds = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'FakeUser', (ConvertTo-SecureString -String 'FakePassword' -AsPlainText -Force)
            $creds | Export-Clixml -Path $script:credentialsFilePath -Force

            [PSCustomObject]@{
                'token'              = 'FakeToken'
                tokenExpiration      = (Get-Date).AddSeconds(3600)
                SkipCertificateCheck = $true
            } | Export-Clixml -Path $script:accessTokenFilePath -Force

            $script:accessToken = Import-Clixml -Path $script:accessTokenFilePath
            $script:Credential = Import-Clixml -Path $script:credentialsFilePath
            $script:configuration = Import-Clixml -Path $script:configurationFilePath
            $script:BaseURLv1 = "https://" + $script:configuration.ServerAddress + ":" + $script:configuration.port + "/sepm/api/v1"
            $script:BaseURLv2 = "https://" + $script:configuration.ServerAddress + ":" + $script:configuration.port + "/sepm/api/v2"
        }

        Context 'token is valid, no SkipCert' {
            BeforeAll {
                Setup-TestModuleState
                $script:SkipCert = $false
                Mock Test-SEPMAccessToken -ModuleName $script:moduleName { return $true }
            }

            It 'returns context object with Headers, BaseURLv1, and BaseURLv2' {
                $result = Initialize-SEPMSession
                $result | Should -BeOfType [PSCustomObject]
                $result.Headers | Should -BeOfType [hashtable]
                $result.Headers['Authorization'] | Should -Be "Bearer FakeToken"
                $result.Headers['Content'] | Should -Be 'application/json'
                $result.BaseURLv1 | Should -Be 'https://FakeServer01:1234/sepm/api/v1'
                $result.BaseURLv2 | Should -Be 'https://FakeServer01:1234/sepm/api/v2'
            }

            It 'does not set SkipCert when switch is not passed' {
                Initialize-SEPMSession | Out-Null
                $script:SkipCert | Should -BeFalse
            }
        }

        Context 'token is valid, SkipCertificateCheck passed' {
            BeforeAll {
                Setup-TestModuleState
                $script:SkipCert = $false
                Mock Test-SEPMAccessToken -ModuleName $script:moduleName { return $true }
            }

            It 'sets SkipCert to true when -SkipCertificateCheck is passed' {
                Initialize-SEPMSession -SkipCertificateCheck | Out-Null
                $script:SkipCert | Should -BeTrue
            }
        }

        Context 'token is expired, refreshes via Get-SEPMAccessToken' {
            BeforeAll {
                Setup-TestModuleState
                Mock Test-SEPMAccessToken -ModuleName $script:moduleName { return $false }
                Mock Get-SEPMAccessToken -ModuleName $script:moduleName { }
            }

            It 'refreshes the token when expired' {
                Initialize-SEPMSession | Out-Null
                Assert-MockCalled Get-SEPMAccessToken -ModuleName $script:moduleName -Exactly 1 -Scope It
            }
        }

        Context 'token is valid, no unnecessary token refresh' {
            BeforeAll {
                Setup-TestModuleState
                Mock Test-SEPMAccessToken -ModuleName $script:moduleName { return $true }
                Mock Get-SEPMAccessToken -ModuleName $script:moduleName { }
            }

            It 'does not refresh the token when still valid' {
                Initialize-SEPMSession | Out-Null
                Assert-MockCalled Get-SEPMAccessToken -ModuleName $script:moduleName -Exactly 0 -Scope It
            }
        }
    }
}
