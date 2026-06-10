[CmdletBinding()]
param()

Describe 'Send-SEPMCommand' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context '-Type ActiveScan -ComputerName with single PC' {
        BeforeAll {
            $fakeSession = New-TestSession
            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }
            Mock Resolve-SepmCommandTarget -ModuleName PSSymantecSEPM {
                return @{ computer_ids = @('ABC123'); group_ids = @() }
            }
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                return @{ command_id = 'CMD-001' }
            }
        }

        It 'POSTs to the correct activescan endpoint with computer_ids' {
            Send-SEPMCommand -Type ActiveScan -ComputerName 'PC1'

            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'POST' -and $Uri -match '/command-queue/activescan' -and $Uri -match 'computer_ids=ABC123'
            }
        }
    }

    Context 'returns array via Write-Output -NoEnumerate' {
        BeforeAll {
            $fakeSession = New-TestSession
            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }
            Mock Resolve-SepmCommandTarget -ModuleName PSSymantecSEPM {
                return @{ computer_ids = @('ABC123'); group_ids = @() }
            }
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                return @{ command_id = 'CMD-001' }
            }
        }

        It 'returns the response without unrolling' {
            $result = Send-SEPMCommand -Type ActiveScan -ComputerName 'PC1'
            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -Be 1
            $result.command_id | Should -Be 'CMD-001'
        }
    }

    Context 'auth bootstrap' {
        BeforeAll {
            $fakeSession = New-TestSession
            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }
            Mock Resolve-SepmCommandTarget -ModuleName PSSymantecSEPM {
                return @{ computer_ids = @('ABC123'); group_ids = @() }
            }
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                return @{ command_id = 'CMD-001' }
            }
        }

        It 'calls Initialize-SEPMSession in begin block' {
            Send-SEPMCommand -Type ActiveScan -ComputerName 'PC1'

            Should -Invoke Initialize-SEPMSession -ModuleName PSSymantecSEPM -Times 1 -Exactly
        }
    }

    Context '-Type ValidateSet' {
        BeforeAll {
            $fakeSession = New-TestSession
            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }
            Mock Resolve-SepmCommandTarget -ModuleName PSSymantecSEPM {
                return @{ computer_ids = @('ABC123'); group_ids = @() }
            }
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                return @{ command_id = 'CMD-001' }
            }
        }

        It 'accepts ActiveScan as a valid -Type value' {
            { Send-SEPMCommand -Type ActiveScan -ComputerName 'PC1' -ErrorAction Stop } | Should -Not -Throw
            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Times 1 -Exactly -ParameterFilter {
                $Uri -match '/command-queue/activescan'
            }
        }
    }

    Context '-Type ActiveScan -ComputerName with multiple PCs' {
        BeforeAll {
            $fakeSession = New-TestSession
            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }
            Mock Resolve-SepmCommandTarget -ModuleName PSSymantecSEPM {
                return @{ computer_ids = @('ID-001', 'ID-002'); group_ids = @() }
            }
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                return @{ command_id = 'CMD-002' }
            }
        }

        It 'resolves multiple computer names to multiple IDs' {
            { Send-SEPMCommand -Type ActiveScan -ComputerName 'PC1', 'PC2' -ErrorAction Stop } | Should -Not -Throw

            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'POST' -and $Uri -match '/command-queue/activescan' -and $Uri -match 'computer_ids=' -and $Uri -match 'ID-001' -and $Uri -match 'ID-002'
            }
        }
    }
}
