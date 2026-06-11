[CmdletBinding()]
param()

Describe 'Get-SEPMApiEndpoint' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context 'registry lookup' {
        It 'returns the registry entry for Get-SEPMVersion' {
            InModuleScope PSSymantecSEPM {
                $entry = Get-SEPMApiEndpoint -OperationName 'Get-SEPMVersion'
                $entry                    | Should -Not -BeNullOrEmpty
                $entry.Version            | Should -Be '1.0'
                $entry.Method             | Should -Be 'GET'
                $entry.Path               | Should -Be '/version'
                $entry.OperationName      | Should -Be 'Get-SEPMVersion'
            }
        }

        It 'New-SEPMGroup has POST method and BodyParams mapping' {
            InModuleScope PSSymantecSEPM {
                $entry = Get-SEPMApiEndpoint -OperationName 'New-SEPMGroup'
                $entry.Method                  | Should -Be 'POST'
                $entry.Path                    | Should -Be '/groups'
                $entry.BodyParams.name         | Should -Be 'GroupName'
                $entry.BodyParams.description  | Should -Be 'Description'
                $entry.BodyParams.inherits     | Should -Be 'EnabledInheritance'
            }
        }

        It 'Remove-SEPMGroup has DELETE method and {id} path' {
            InModuleScope PSSymantecSEPM {
                $entry = Get-SEPMApiEndpoint -OperationName 'Remove-SEPMGroup'
                $entry.Method | Should -Be 'DELETE'
                $entry.Path   | Should -Be '/groups/{id}'
            }
        }

        It 'Add-SEPMFileFingerprintList has POST method and BodyParams mapping' {
            InModuleScope PSSymantecSEPM {
                $entry = Get-SEPMApiEndpoint -OperationName 'Add-SEPMFileFingerprintList'
                $entry.Method            | Should -Be 'POST'
                $entry.Path              | Should -Be '/policy-objects/fingerprints'
                $entry.BodyParams.name   | Should -Be 'name'
                $entry.BodyParams.data   | Should -Be 'hashlist'
            }
        }

        It 'Remove-SEPMFileFingerprintList has DELETE method and {id} path' {
            InModuleScope PSSymantecSEPM {
                $entry = Get-SEPMApiEndpoint -OperationName 'Remove-SEPMFileFingerprintList'
                $entry.Method | Should -Be 'DELETE'
                $entry.Path   | Should -Be '/policy-objects/fingerprints/{id}'
            }
        }

        It 'Update-SEPMFileFingerprintList has POST method and BodyParams' {
            InModuleScope PSSymantecSEPM {
                $entry = Get-SEPMApiEndpoint -OperationName 'Update-SEPMFileFingerprintList'
                $entry.Method            | Should -Be 'POST'
                $entry.Path              | Should -Be '/policy-objects/fingerprints/{id}'
                $entry.BodyParams.name   | Should -Be 'name'
                $entry.BodyParams.data   | Should -Be 'hashlist'
            }
        }

        It 'Start-SEPMReplication has POST method and QueryParams' {
            InModuleScope PSSymantecSEPM {
                $entry = Get-SEPMApiEndpoint -OperationName 'Start-SEPMReplication'
                $entry.Method                        | Should -Be 'POST'
                $entry.Path                          | Should -Be '/replication/replicatenow'
                $entry.QueryParams.partnerSiteName    | Should -Be 'partnerSiteName'
            }
        }

        It 'Move-SEPClientGroup has PATCH method' {
            InModuleScope PSSymantecSEPM {
                $entry = Get-SEPMApiEndpoint -OperationName 'Move-SEPClientGroup'
                $entry.Method | Should -Be 'PATCH'
                $entry.Path   | Should -Be '/computers'
            }
        }
    }
}
