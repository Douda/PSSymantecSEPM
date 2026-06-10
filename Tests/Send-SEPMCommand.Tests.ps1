[CmdletBinding()]
param()

Describe 'Send-SEPMCommand' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment

        $script:TestSession = New-TestSession
        Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $script:TestSession }
        Mock Resolve-SepmCommandTarget -ModuleName PSSymantecSEPM {
            return @{ computer_ids = @('ABC123'); group_ids = @() }
        }
        Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
            return @{ command_id = 'CMD-001' }
        }
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context 'single computer dispatch' {
        It 'POSTs to the correct activescan endpoint with computer_ids' {
            Send-SEPMCommand -Type ActiveScan -ComputerName 'PC1'

            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'POST' -and $Uri -match '/command-queue/activescan' -and $Uri -match 'computer_ids=ABC123'
            }
        }

        It 'bootstraps authentication via Initialize-SEPMSession' {
            Send-SEPMCommand -Type ActiveScan -ComputerName 'PC1'

            Should -Invoke Initialize-SEPMSession -ModuleName PSSymantecSEPM -Times 1 -Exactly
        }

        It 'returns the response via Write-Output -NoEnumerate' {
            $result = Send-SEPMCommand -Type ActiveScan -ComputerName 'PC1'
            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -Be 1
            $result.command_id | Should -Be 'CMD-001'
        }
    }

    Context 'multiple computer dispatch' {
        BeforeAll {
            Mock Resolve-SepmCommandTarget -ModuleName PSSymantecSEPM {
                return @{ computer_ids = @('ID-001', 'ID-002'); group_ids = @() }
            }
        }

        It 'resolves multiple computer names to multiple IDs' {
            { Send-SEPMCommand -Type ActiveScan -ComputerName 'PC1', 'PC2' -ErrorAction Stop } | Should -Not -Throw

            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'POST' -and $Uri -match '/command-queue/activescan' -and $Uri -match 'computer_ids=' -and $Uri -match 'ID-001' -and $Uri -match 'ID-002'
            }
        }
    }

    Context 'FullScan dispatch' {
        It 'POSTs to the correct fullscan endpoint with computer_ids' {
            Send-SEPMCommand -Type FullScan -ComputerName 'PC1'

            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'POST' -and $Uri -match '/command-queue/fullscan' -and $Uri -match 'computer_ids=ABC123'
            }
        }
    }

    Context 'UpdateContent dispatch' {
        It 'POSTs to the correct updatecontent endpoint with computer_ids' {
            Send-SEPMCommand -Type UpdateContent -ComputerName 'PC1'

            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'POST' -and $Uri -match '/command-queue/updatecontent' -and $Uri -match 'computer_ids=ABC123'
            }
        }
    }

    Context 'Quarantine dispatch' {
        It 'POSTs to the correct quarantine endpoint with computer_ids' {
            Send-SEPMCommand -Type Quarantine -ComputerName 'PC1'

            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'POST' -and $Uri -match '/command-queue/quarantine' -and $Uri -match 'computer_ids=ABC123'
            }
        }

        It 'does not include undo in query params when -Undo is not specified' {
            Send-SEPMCommand -Type Quarantine -ComputerName 'PC1'

            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'POST' -and $Uri -notmatch 'undo='
            }
        }

        It 'includes undo=True in query params when -Undo switch is used' {
            Send-SEPMCommand -Type Quarantine -ComputerName 'PC1' -Undo

            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'POST' -and $Uri -match '/command-queue/quarantine' -and $Uri -match 'computer_ids=ABC123' -and $Uri -match 'undo=True'
            }
        }
    }
}
