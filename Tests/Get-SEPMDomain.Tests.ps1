[CmdletBinding()]
param()

Describe 'Get-SEPMDomain' {
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
        It 'returns domain list from the API' {
            $fakeSession = New-TestSession -SkipCert

            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM -ParameterFilter {
                $Method -eq 'GET' -and $Uri -match '/domains$'
            } {
                return @(
                    @{ id = 'abc123'; name = 'Default'; description = ''; createdTime = 1360247301316; enable = $true }
                    @{ id = 'def456'; name = 'Secondary'; description = 'test'; createdTime = 1360247301317; enable = $false }
                )
            }

            $result = Get-SEPMDomain
            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -Be 2
            $result[0].name | Should -Be 'Default'
            $result[1].name | Should -Be 'Secondary'
        }

        It 'passes session to Invoke-SepmApi' {
            $fakeSession = New-TestSession -Token 'DomainToken'

            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM { return @() }

            Get-SEPMDomain | Out-Null
            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'GET' -and
                $null -ne $Session -and
                $Session.Headers.Authorization -eq 'Bearer DomainToken'
            }
        }
    }
}
