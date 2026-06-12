[CmdletBinding()]
param()

Describe 'Build-SepmBody' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context 'with BodyParams declared' {
        BeforeAll {
            $script:endpointWithBodyParams = @{
                OperationName = 'New-SEPMGroup'
                Version       = '1.0'
                Method        = 'POST'
                Path          = '/groups'
                BodyParams    = @{
                    name        = 'GroupName'
                    description = 'Description'
                    inherits    = 'EnabledInheritance'
                }
            }
        }

        It 'returns null when no BoundParameters match' {
            InModuleScope PSSymantecSEPM -Parameters @{ Endpoint = $script:endpointWithBodyParams } {
                $result = Build-SepmBody -Endpoint $Endpoint -BoundParameters @{}
                $result | Should -BeNullOrEmpty
            }
        }

        It 'builds JSON body from BoundParameters mapping' {
            InModuleScope PSSymantecSEPM -Parameters @{ Endpoint = $script:endpointWithBodyParams } {
                $bound = @{
                    GroupName          = 'Win7'
                    Description        = 'Test group'
                    EnabledInheritance = $false
                }
                $result = Build-SepmBody -Endpoint $Endpoint -BoundParameters $bound
                $result | Should -Not -BeNullOrEmpty
                $bodyObj = $result | ConvertFrom-Json
                $bodyObj.name        | Should -Be 'Win7'
                $bodyObj.description | Should -Be 'Test group'
                $bodyObj.inherits    | Should -BeFalse
            }
        }

        It 'converts switch parameters to boolean' {
            InModuleScope PSSymantecSEPM -Parameters @{ Endpoint = $script:endpointWithBodyParams } {
                $bound = @{ EnabledInheritance = $true }
                $result = Build-SepmBody -Endpoint $Endpoint -BoundParameters $bound
                $bodyObj = $result | ConvertFrom-Json
                $bodyObj.inherits | Should -BeTrue
            }
        }

        It 'omits null and empty string values' {
            InModuleScope PSSymantecSEPM -Parameters @{ Endpoint = $script:endpointWithBodyParams } {
                $bound = @{ GroupName = 'Test'; Description = '' }
                $result = Build-SepmBody -Endpoint $Endpoint -BoundParameters $bound
                $bodyObj = $result | ConvertFrom-Json
                $bodyObj.name | Should -Be 'Test'
                $bodyObj.PSObject.Properties.Name | Should -Not -Contain 'description'
            }
        }
    }

    Context 'with pre-serialized Body' {
        It 'returns Body as-is when provided' {
            InModuleScope PSSymantecSEPM {
                $result = Build-SepmBody -Endpoint @{} -Body '{"custom":true}'
                $result | Should -Be '{"custom":true}'
            }
        }

        It 'returns Body as-is even when BodyParams are declared' {
            InModuleScope PSSymantecSEPM {
                $endpoint = @{ BodyParams = @{ name = 'Name' } }
                $result = Build-SepmBody -Endpoint $endpoint -BoundParameters @{ Name = 'ignored' } -Body '{"override":true}'
                $result | Should -Be '{"override":true}'
            }
        }
    }

    Context 'with no BodyParams and no Body' {
        It 'returns null' {
            InModuleScope PSSymantecSEPM {
                $result = Build-SepmBody -Endpoint @{}
                $result | Should -BeNullOrEmpty
            }
        }
    }
}
