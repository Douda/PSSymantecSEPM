[CmdletBinding()]
param()

Describe 'Get-SEPMClientInfectedStatus' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context 'infected status' {
        BeforeAll {
            $script:infectedComputers = @(
                [PSCustomObject]@{ computerName = 'PC01'; infected = 1 }
                [PSCustomObject]@{ computerName = 'PC02'; infected = 0 }
                [PSCustomObject]@{ computerName = 'PC03'; infected = 1 }
                [PSCustomObject]@{ computerName = 'PC04'; infected = 0 }
            )
        }

        AfterEach {
            # Reset the mock after each test so we can verify invocation counts
        }
        It 'returns infected computers (infected=1)' {
            Mock Get-SEPMComputers -ModuleName PSSymantecSEPM { return $script:infectedComputers }

            $result = Get-SEPMClientInfectedStatus
            $result.Count | Should -Be 2
            $result[0].computerName | Should -Be 'PC01'
            $result[1].computerName | Should -Be 'PC03'
            $result[0].infected | Should -Be 1
            $result[1].infected | Should -Be 1
        }

        It 'returns clean computers when -Clean is specified' {
            Mock Get-SEPMComputers -ModuleName PSSymantecSEPM { return $script:infectedComputers }

            $result = Get-SEPMClientInfectedStatus -Clean
            $result.Count | Should -Be 2
            $result[0].computerName | Should -Be 'PC02'
            $result[1].computerName | Should -Be 'PC04'
            $result[0].infected | Should -Be 0
            $result[1].infected | Should -Be 0
        }

        It 'returns empty array when no computers match' {
            Mock Get-SEPMComputers -ModuleName PSSymantecSEPM {
                return @(
                    [PSCustomObject]@{ computerName = 'PC01'; infected = 0 }
                    [PSCustomObject]@{ computerName = 'PC02'; infected = 0 }
                )
            }

            $result = Get-SEPMClientInfectedStatus
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'ComputerList parameter' {
        BeforeAll {
            $script:computerList = @(
                [PSCustomObject]@{ computerName = 'PC01'; infected = 1 }
                [PSCustomObject]@{ computerName = 'PC02'; infected = 0 }
                [PSCustomObject]@{ computerName = 'PC03'; infected = 1 }
                [PSCustomObject]@{ computerName = 'PC04'; infected = 0 }
            )
        }

        It 'filters by infected status from passed list without calling Get-SEPComputers' {
            Mock Get-SEPComputers -ModuleName PSSymantecSEPM { throw 'Get-SEPComputers should not be called' }

            $result = Get-SEPClientInfectedStatus -ComputerList $script:computerList
            $result.Count | Should -Be 2
            $result[0].computerName | Should -Be 'PC01'
            $result[1].computerName | Should -Be 'PC03'
        }

        It 'filters by clean status from passed list with -ComputerList -Clean' {
            Mock Get-SEPComputers -ModuleName PSSymantecSEPM { throw 'Get-SEPComputers should not be called' }

            $result = Get-SEPClientInfectedStatus -ComputerList $script:computerList -Clean
            $result.Count | Should -Be 2
            $result[0].computerName | Should -Be 'PC02'
            $result[1].computerName | Should -Be 'PC04'
            $result[0].infected | Should -Be 0
            $result[1].infected | Should -Be 0
        }

        It 'returns empty when -ComputerList has no infected matches' {
            Mock Get-SEPComputers -ModuleName PSSymantecSEPM { throw 'Get-SEPComputers should not be called' }

            $cleanOnly = @(
                [PSCustomObject]@{ computerName = 'PC01'; infected = 0 }
                [PSCustomObject]@{ computerName = 'PC02'; infected = 0 }
            )
            $result = Get-SEPClientInfectedStatus -ComputerList $cleanOnly
            $result | Should -BeNullOrEmpty
        }

        It 'returns empty when -ComputerList -Clean has no clean matches' {
            Mock Get-SEPComputers -ModuleName PSSymantecSEPM { throw 'Get-SEPComputers should not be called' }

            $infectedOnly = @(
                [PSCustomObject]@{ computerName = 'PC01'; infected = 1 }
                [PSCustomObject]@{ computerName = 'PC02'; infected = 1 }
            )
            $result = Get-SEPClientInfectedStatus -ComputerList $infectedOnly -Clean
            $result | Should -BeNullOrEmpty
        }

        It 'preserves all properties from passed computer objects' {
            Mock Get-SEPComputers -ModuleName PSSymantecSEPM { throw 'Get-SEPComputers should not be called' }

            $richList = @(
                [PSCustomObject]@{ computerName = 'PC01'; infected = 1; group = 'My Group'; ipAddresses = @('10.0.0.1') }
                [PSCustomObject]@{ computerName = 'PC02'; infected = 0; group = 'Other Group'; ipAddresses = @('10.0.0.2') }
            )
            $result = Get-SEPClientInfectedStatus -ComputerList $richList
            $result.Count | Should -Be 1
            $result[0].computerName | Should -Be 'PC01'
            $result[0].group | Should -Be 'My Group'
            $result[0].ipAddresses[0] | Should -Be '10.0.0.1'
        }
    }
}
