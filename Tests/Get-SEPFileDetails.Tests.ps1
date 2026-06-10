[CmdletBinding()]
param()

Describe 'Get-SEPFileDetails' {
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

        It 'returns file details with expected fields' {
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                return @{
                    id       = 'CD02BC8E0A6606D53533F2428BB86D4E'
                    fileSize = 1071101
                    checksum = '4BE0BB3B57044CAD186FB59C2B7A13BB'
                }
            }

            $result = Get-SEPFileDetails -FileID 'CD02BC8E0A6606D53533F2428BB86D4E'
            $result.id       | Should -Be 'CD02BC8E0A6606D53533F2428BB86D4E'
            $result.fileSize | Should -Be 1071101
            $result.checksum | Should -Be '4BE0BB3B57044CAD186FB59C2B7A13BB'
        }

        It 'calls the correct API endpoint' {
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                return @{ id = 'ABC'; fileSize = 0; checksum = 'DEF' }
            }

            Get-SEPFileDetails -FileID 'TEST123' | Out-Null
            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'GET' -and $Uri -match '/command-queue/file/TEST123/details'
            }
        }

        It 'handles response with null fields gracefully' {
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                return @{
                    id       = 'NULLTEST'
                    fileSize = $null
                    checksum = $null
                }
            }

            $result = Get-SEPFileDetails -FileID 'NULLTEST'
            $result.id       | Should -Be 'NULLTEST'
            $result.fileSize | Should -BeNullOrEmpty
        }
    }
}
