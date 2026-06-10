[CmdletBinding()]
param()

Describe 'Get-SEPClientInfectedStatus' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context 'infected status' {
        It 'returns infected computers (infected=1)' {
            Mock Get-SEPComputers -ModuleName PSSymantecSEPM {
                return @(
                    [PSCustomObject]@{ computerName = 'PC01'; infected = 1 }
                    [PSCustomObject]@{ computerName = 'PC02'; infected = 0 }
                    [PSCustomObject]@{ computerName = 'PC03'; infected = 1 }
                    [PSCustomObject]@{ computerName = 'PC04'; infected = 0 }
                )
            }

            $result = Get-SEPClientInfectedStatus
            $result.Count | Should -Be 2
            $result[0].computerName | Should -Be 'PC01'
            $result[1].computerName | Should -Be 'PC03'
            $result[0].infected | Should -Be 1
            $result[1].infected | Should -Be 1
        }

        It 'returns clean computers when -Clean is specified' {
            Mock Get-SEPComputers -ModuleName PSSymantecSEPM {
                return @(
                    [PSCustomObject]@{ computerName = 'PC01'; infected = 1 }
                    [PSCustomObject]@{ computerName = 'PC02'; infected = 0 }
                    [PSCustomObject]@{ computerName = 'PC03'; infected = 1 }
                )
            }

            $result = Get-SEPClientInfectedStatus -Clean
            $result.Count | Should -Be 1
            $result[0].computerName | Should -Be 'PC02'
            $result[0].infected | Should -Be 0
        }

        It 'returns empty array when no computers match' {
            Mock Get-SEPComputers -ModuleName PSSymantecSEPM {
                return @(
                    [PSCustomObject]@{ computerName = 'PC01'; infected = 0 }
                    [PSCustomObject]@{ computerName = 'PC02'; infected = 0 }
                )
            }

            $result = Get-SEPClientInfectedStatus
            $result | Should -BeNullOrEmpty
        }
    }
}
