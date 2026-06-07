[CmdletBinding()]
param()

Describe 'Get-SEPMAdmins' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment

        InModuleScope PSSymantecSEPM {
            $script:configurationFilePath = Join-Path -Path 'TestDrive:' -ChildPath 'config.json'
            $script:credentialsFilePath   = Join-Path -Path 'TestDrive:' -ChildPath 'creds.xml'
            $script:accessTokenFilePath   = Join-Path -Path 'TestDrive:' -ChildPath 'token.xml'
            $script:configuration = @{ domain = 'Default' }
        }
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context 'Session-based flow' {
        BeforeAll {
            $fakeSession = New-TestSession -SkipCert

            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                return @(
                    @{ loginName = 'admin'; email = 'admin@test.com'; role = 'Administrator' }
                    @{ loginName = 'smokeuser'; email = 'smoke@test.com'; role = 'Limited Administrator' }
                )
            }
        }

        It 'returns all admins when no filter' {
            $result = Get-SEPMAdmins
            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -Be 2
            $result[0].loginName | Should -Be 'admin'
        }

        It 'filters to the specified admin' {
            $result = Get-SEPMAdmins -AdminName 'admin'
            $result | Should -Not -BeNullOrEmpty
            $result.loginName | Should -Be 'admin'
        }
    }
}
