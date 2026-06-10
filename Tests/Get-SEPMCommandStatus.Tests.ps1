[CmdletBinding()]
param()

Describe 'Get-SEPMCommandStatus' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context 'happy path' {
        BeforeAll {
            $fakeSession = New-TestSession
            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }
        }

        It 'returns command status with SEPM.CommandStatus type (single page)' {
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                return @{
                    content     = @(
                        @{
                            beginTime            = $null
                            lastUpdateTime       = '2026-06-07 17:30:00'
                            computerName         = 'MyWorkstation01'
                            computerIp           = '192.168.1.1'
                            domainName           = 'Default'
                            currentLoginUserName = 'localadmin'
                            stateId              = 0
                            subStateId           = 0
                            subStateDesc         = ''
                            binaryFileId         = $null
                            resultInXML          = $null
                            computerId           = 'ABCDEF1234567890ABCDEF1234567890'
                            hardwareKey          = 'ABCDEF1234567890ABCDEF1234567890'
                        }
                    )
                    totalPages = 1
                    lastPage   = $true
                }
            }

            $result = Get-SEPMCommandStatus -Command_ID 'CMD123'
            $result.Count | Should -Be 1
            $result[0].computerName | Should -Be 'MyWorkstation01'
            $result[0].stateId      | Should -Be 0
            $result[0].PSObject.TypeNames[0] | Should -Be 'SEPM.CommandStatus'
        }

        It 'calls the correct API endpoint' {
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                return @{ content = @(); totalPages = 1; lastPage = $true }
            }

            Get-SEPMCommandStatus -Command_ID 'CMD789' | Out-Null
            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'GET' -and $Uri -match '/command-queue/CMD789'
            }
        }
    }
}
