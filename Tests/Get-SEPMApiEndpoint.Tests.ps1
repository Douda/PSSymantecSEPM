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
    }
}
