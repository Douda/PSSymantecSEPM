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

    Context 'Path ID substitution' {
        BeforeAll {
            $fakeSession = New-TestSession -ServerAddress 'sepm.example.com' -Port '8446' -Token 'abc123'
        }

        It 'replaces a single {id} placeholder with a PathIds element' {
            $endpoint = @{
                OperationName = 'Get-Foo'
                Version       = '1.0'
                Method        = 'GET'
                Path          = '/policies/exceptions/{id}'
            }

            InModuleScope PSSymantecSEPM -Parameters @{ Endpoint = $endpoint; Session = $fakeSession } {
                $uri = Resolve-SepmEndpoint -Endpoint $Endpoint -Session $Session -PathIds @('POL123')
                $uri | Should -Be 'https://sepm.example.com:8446/sepm/api/v1/policies/exceptions/POL123'
            }
        }

        It 'replaces multiple {id} placeholders in order' {
            $endpoint = @{
                OperationName = 'Get-Foo'
                Version       = '1.0'
                Method        = 'GET'
                Path          = '/groups/{id}/locations/{id}/settings'
            }

            InModuleScope PSSymantecSEPM -Parameters @{ Endpoint = $endpoint; Session = $fakeSession } {
                $uri = Resolve-SepmEndpoint -Endpoint $Endpoint -Session $Session -PathIds @('GRP001', 'LOC456')
                $uri | Should -Be 'https://sepm.example.com:8446/sepm/api/v1/groups/GRP001/locations/LOC456/settings'
            }
        }

        It 'appends a single PathIds element when path has no {id} placeholder' {
            $endpoint = @{
                OperationName = 'Get-Foo'
                Version       = '1.0'
                Method        = 'GET'
                Path          = '/policies/firewall'
            }

            InModuleScope PSSymantecSEPM -Parameters @{ Endpoint = $endpoint; Session = $fakeSession } {
                $uri = Resolve-SepmEndpoint -Endpoint $Endpoint -Session $Session -PathIds @('FW001')
                $uri | Should -Be 'https://sepm.example.com:8446/sepm/api/v1/policies/firewall/FW001'
            }
        }

        It 'leaves path unchanged when PathIds is empty and path has no {id}' {
            $endpoint = @{
                OperationName = 'Get-Foo'
                Version       = '1.0'
                Method        = 'GET'
                Path          = '/version'
            }

            InModuleScope PSSymantecSEPM -Parameters @{ Endpoint = $endpoint; Session = $fakeSession } {
                $uri = Resolve-SepmEndpoint -Endpoint $Endpoint -Session $Session -PathIds @()
                $uri | Should -Be 'https://sepm.example.com:8446/sepm/api/v1/version'
            }
        }

        It 'replaces {id} with version 2.0 endpoint' {
            $endpoint = @{
                OperationName = 'Get-Foo'
                Version       = '2.0'
                Method        = 'GET'
                Path          = '/policies/exceptions/{id}'
            }

            InModuleScope PSSymantecSEPM -Parameters @{ Endpoint = $endpoint; Session = $fakeSession } {
                $uri = Resolve-SepmEndpoint -Endpoint $Endpoint -Session $Session -PathIds @('EXC001')
                $uri | Should -Be 'https://sepm.example.com:8446/sepm/api/v2/policies/exceptions/EXC001'
            }
        }
    }
}
