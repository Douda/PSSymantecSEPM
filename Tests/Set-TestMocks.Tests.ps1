[CmdletBinding()]
param()

Describe 'Set-TestMocks' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context 'basic usage' {
        It 'wires Initialize-SEPMSession and Invoke-SepmApi mocks, transport output is returned' {
            $session = Set-TestMocks -Transport {
                return @{ API_SEQUENCE = 'TEST001'; API_VERSION = '99.9.9999'; version = '99.9.9999.9999' }
            }

            $result = Get-SEPMVersion
            $result.API_SEQUENCE | Should -Be 'TEST001'
            $result.API_VERSION  | Should -Be '99.9.9999'
            $result.version      | Should -Be '99.9.9999.9999'
        }

        It 'returns the session handle to the caller' {
            $session = Set-TestMocks -Transport { return @{ ok = $true } }

            $session | Should -Not -BeNullOrEmpty
            $session.Headers.Authorization | Should -Be 'Bearer FakeToken'
            $session.BaseURLv1 | Should -Match 'https://FakeServer01:1234/sepm/api/v1'
            $session.BaseURLv2 | Should -Match 'https://FakeServer01:1234/sepm/api/v2'
            $session.SkipCert | Should -Be $false
        }

        It 'passes the session with correct token to Invoke-SepmApi' {
            $null = Set-TestMocks -Transport { return @{ ok = $true } }

            Get-SEPMVersion | Out-Null
            Should -Invoke Initialize-SEPMSession -ModuleName PSSymantecSEPM -Times 1 -Exactly
            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Times 1 -Exactly -ParameterFilter {
                $null -ne $Session -and
                $Session.Headers.Authorization -eq 'Bearer FakeToken'
            }
        }
    }

    Context 'SkipCert forwarding' {
        It 'forwards SkipCert to session when -SkipCert is used' {
            $session = Set-TestMocks -Transport { return @{ ok = $true } } -SkipCert

            $session.SkipCert | Should -Be $true
        }

        It 'does not set SkipCert by default' {
            $session = Set-TestMocks -Transport { return @{ ok = $true } }

            $session.SkipCert | Should -Be $false
        }
    }

    Context 'Token forwarding' {
        It 'forwards -Token to the session' {
            $session = Set-TestMocks -Transport { return @{ ok = $true } } -Token 'CustomToken123'

            $session.Headers.Authorization | Should -Be 'Bearer CustomToken123'
        }

        It 'uses custom token in Invoke-SepmApi call' {
            $session = Set-TestMocks -Transport { return @{ ok = $true } } -Token 'CustomToken456'

            Get-SEPMVersion | Out-Null
            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Times 1 -Exactly -ParameterFilter {
                $null -ne $Session -and
                $Session.Headers.Authorization -eq 'Bearer CustomToken456'
            }
        }
    }
}
