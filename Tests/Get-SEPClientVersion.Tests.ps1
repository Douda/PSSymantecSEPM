[CmdletBinding()]
param()

Describe 'Get-SEPClientVersion' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment

        InModuleScope PSSymantecSEPM {
            $script:configurationFilePath = Join-Path -Path 'TestDrive:' -ChildPath 'config.json'
            $script:credentialsFilePath   = Join-Path -Path 'TestDrive:' -ChildPath 'creds.xml'
            $script:accessTokenFilePath   = Join-Path -Path 'TestDrive:' -ChildPath 'token.xml'
        }
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context 'Session-based flow' {
        It 'returns client version list with version and count fields' {
            $fakeSession = New-TestSession -SkipCert

            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM -ParameterFilter {
                $Method -eq 'GET' -and $Uri -match '/stats/client/version$'
            } {
                return @{
                    clientVersionList = @(
                        @{ version = '14.3.558.0000'; clientsCount = 5; formattedVersion = '14.3 (14.3) build 0000' }
                        @{ version = '14.2.1031.0100'; clientsCount = 21; formattedVersion = '14.2.1 (14.2 RU1) build 0100' }
                    )
                }
            }

            $result = Get-SEPClientVersion
            $result.Count | Should -Be 2
            $result[0].version | Should -Be '14.3.558.0000'
            $result[0].clientsCount | Should -Be 5
            $result[1].version | Should -Be '14.2.1031.0100'
        }
    }
}
