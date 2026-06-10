[CmdletBinding()]
param()

Describe 'Resolve-SepmEndpoint' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context 'URI resolution' {
        BeforeAll {
            $fakeSession = New-TestSession -ServerAddress 'sepm.example.com' -Port '8446' -Token 'abc123'

            $endpoint = @{
                OperationName = 'Get-SEPMVersion'
                Version       = '1.0'
                Method        = 'GET'
                Path          = '/version'
            }
        }

        It 'resolves a simple GET endpoint to a full URI using BaseURLv1' {
            InModuleScope PSSymantecSEPM -Parameters @{ Endpoint = $endpoint; Session = $fakeSession } {
                $uri = Resolve-SepmEndpoint -Endpoint $Endpoint -Session $Session
                $uri | Should -Be 'https://sepm.example.com:8446/sepm/api/v1/version'
            }
        }

        It 'resolves a version 2.0 endpoint using BaseURLv2' {
            InModuleScope PSSymantecSEPM -Parameters @{ Endpoint = (@{
                OperationName = 'SomeV2Op'
                Version       = '2.0'
                Method        = 'GET'
                Path          = '/computers'
            }); Session = $fakeSession } {
                $uri = Resolve-SepmEndpoint -Endpoint $Endpoint -Session $Session
                $uri | Should -Be 'https://sepm.example.com:8446/sepm/api/v2/computers'
            }
        }
    }
}
