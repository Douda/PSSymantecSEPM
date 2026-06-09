[CmdletBinding()]
param()

Describe 'Start-SEPScan' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context 'ComputerName - ActiveScan' {
        BeforeAll {
            $fakeSession = New-TestSession
            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }

            Mock Get-SEPComputers -ModuleName PSSymantecSEPM {
                param($ComputerName)
                return [PSCustomObject]@{ computerName = $ComputerName; uniqueId = 'UID-111111' }
            }

            $script:apiCalls = @()
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                $script:apiCalls += [PSCustomObject]@{
                    Method = $Method
                    Uri    = $Uri
                }
                return @{ commandId = 'CMD-ACTIVE-001' }
            }
        }

        It 'sends POST to /command-queue/activescan' {
            Start-SEPScan -ComputerName 'MyPC' -ActiveScan

            $script:apiCalls.Count | Should -Be 1
            $script:apiCalls[0].Method | Should -Be 'POST'
            $script:apiCalls[0].Uri    | Should -Match ([regex]::Escape($fakeSession.BaseURLv1 + '/command-queue/activescan'))
        }

        It 'includes computer_ids in query string' {
            Start-SEPScan -ComputerName 'Workstation01' -ActiveScan

            $script:apiCalls.Count | Should -Be 2
            $script:apiCalls[1].Uri | Should -Match 'computer_ids=UID-111111'
        }

        It 'returns the Invoke-SepmApi response' {
            $result = Start-SEPScan -ComputerName 'TestPC' -ActiveScan

            $result.commandId | Should -Be 'CMD-ACTIVE-001'
        }
    }

    Context 'ComputerName - FullScan' {
        BeforeAll {
            $fakeSession = New-TestSession
            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }

            Mock Get-SEPComputers -ModuleName PSSymantecSEPM {
                param($ComputerName)
                return [PSCustomObject]@{ computerName = $ComputerName; uniqueId = 'UID-FULLSCAN' }
            }

            $script:apiCalls = @()
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                $script:apiCalls += [PSCustomObject]@{
                    Method = $Method
                    Uri    = $Uri
                }
                return @{ commandId = 'CMD-FULL-001' }
            }
        }

        It 'sends POST to /command-queue/fullscan' {
            Start-SEPScan -ComputerName 'Server01' -FullScan

            $script:apiCalls.Count | Should -Be 1
            $script:apiCalls[0].Method | Should -Be 'POST'
            $script:apiCalls[0].Uri    | Should -Match ([regex]::Escape($fakeSession.BaseURLv1 + '/command-queue/fullscan'))
        }

        It 'resolves computer name to uniqueId via Get-SEPComputers' {
            Start-SEPScan -ComputerName 'ServerDB' -FullScan

            $script:apiCalls.Count | Should -Be 2
            $script:apiCalls[1].Uri | Should -Match 'computer_ids=UID-FULLSCAN'
            $script:apiCalls[1].Uri | Should -Match '/command-queue/fullscan'
        }
    }

    Context 'pipeline input' {
        BeforeAll {
            $fakeSession = New-TestSession
            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }

            $script:uidCounter = 0
            Mock Get-SEPComputers -ModuleName PSSymantecSEPM {
                param($ComputerName)
                $script:uidCounter++
                return [PSCustomObject]@{ computerName = $ComputerName; uniqueId = "UID-$script:uidCounter" }
            }

            $script:apiCalls = @()
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                $script:apiCalls += [PSCustomObject]@{
                    Method = $Method
                    Uri    = $Uri
                }
                return @{ commandId = 'CMD-PIPE' }
            }
        }

        It 'processes multiple computers via pipeline' {
            'PC-A', 'PC-B' | Start-SEPScan -FullScan

            $script:apiCalls.Count | Should -Be 2
            $script:apiCalls[0].Uri | Should -Match 'computer_ids=UID-1'
            $script:apiCalls[1].Uri | Should -Match 'computer_ids=UID-2'
        }
    }
}
