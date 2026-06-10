[CmdletBinding()]
param()

Describe 'Invoke-SepmEndpoint' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context 'dispatch to transport' {
        BeforeAll {
            $fakeSession = New-TestSession -ServerAddress 'sepm.example.com' -Port '8446' -Token 'abc123'

            $endpoint = @{
                OperationName = 'Get-SEPMVersion'
                Version       = '1.0'
                Method        = 'GET'
                Path          = '/version'
            }
        }

        It 'calls Invoke-SepmApi with resolved URI, Method, and Session' {
            InModuleScope PSSymantecSEPM -Parameters @{ Endpoint = $endpoint; Session = $fakeSession } {
                Mock Invoke-SepmApi { return @{ ok = $true } }

                $result = Invoke-SepmEndpoint -Endpoint $Endpoint -Session $Session

                $result.ok | Should -Be $true

                Should -Invoke Invoke-SepmApi -Times 1 -Exactly -ParameterFilter {
                    $Method -eq 'GET' -and
                    $Uri -eq 'https://sepm.example.com:8446/sepm/api/v1/version' -and
                    $null -ne $Session -and
                    $Session.Headers.Authorization -eq 'Bearer abc123'
                }
            }
        }

        It 'returns the result from Invoke-SepmApi' {
            InModuleScope PSSymantecSEPM -Parameters @{ Endpoint = $endpoint; Session = $fakeSession } {
                Mock Invoke-SepmApi {
                    return @{
                        API_SEQUENCE = '230504014'
                        API_VERSION  = '14.3.7000'
                        version      = '14.3.9816.7000'
                    }
                }

                $result = Invoke-SepmEndpoint -Endpoint $Endpoint -Session $Session

                $result.API_SEQUENCE | Should -Be '230504014'
                $result.API_VERSION  | Should -Be '14.3.7000'
                $result.version      | Should -Be '14.3.9816.7000'
            }
        }
    }
}
