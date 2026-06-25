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
        It 'returns command status with SEPM.CommandStatus type' {
            $null = Set-TestMocks -Transport {
                return @{
                    content = @(
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
                    lastPage  = $true
                    totalPages = 1
                }
            }

            $result = Get-SEPMCommandStatus -Command_ID 'CMD123'
            $result.Count | Should -Be 1
            $result[0].computerName | Should -Be 'MyWorkstation01'
            $result[0].stateId      | Should -Be 0
            $result[0].PSObject.TypeNames[0] | Should -Be 'SEPM.CommandStatus'
        }

        It 'calls Invoke-SepmEndpoint with the correct parameters' {
            $null = Set-TestMocks -Transport {
                return @{ content = @(); lastPage = $true; totalPages = 1 }
            }
            Mock Invoke-SepmEndpoint -ModuleName PSSymantecSEPM {
                return @()
            }

            Get-SEPMCommandStatus -Command_ID 'CMD789' | Out-Null
            Should -Invoke Invoke-SepmEndpoint -ModuleName PSSymantecSEPM -Times 1 -Exactly -ParameterFilter {
                $Endpoint.OperationName -eq 'Get-SEPMCommandStatus' -and $PathIds[0] -eq 'CMD789'
            }
        }
    }
}
