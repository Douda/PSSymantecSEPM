[CmdletBinding()]
param()

Describe 'Send-SEPMCommandGetFile' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context 'SHA256Hash parameter set' {
        BeforeAll {
            $fakeSession = New-TestSession
            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }
            Mock Get-SEPComputers -ModuleName PSSymantecSEPM {
                return [PSCustomObject]@{ uniqueId = 'FILE-TARGET-001'; computerName = 'FileTarget' }
            }
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                return @{ command_id = 'CMD-FILE-001' }
            }
        }

        It 'POSTs to the command-queue/files endpoint' {
            Send-SEPMCommandGetFile -ComputerName 'FileTarget' -SHA256 'ABCDEF1234567890ABCDEF1234567890ABCDEF1234567890ABCDEF1234567890' -FilePath 'C:\Temp\malware.exe' -Source 'BOTH'

            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'POST' -and $Uri -match '/command-queue/files'
            }
        }

        It 'includes computer_ids in URI query string' {
            Send-SEPMCommandGetFile -ComputerName 'FileTarget' -SHA256 'ABCDEF1234567890ABCDEF1234567890ABCDEF1234567890ABCDEF1234567890' -FilePath 'C:\Temp\malware.exe' -Source 'BOTH'

            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'POST' -and $Uri -match 'computer_ids=FILE-TARGET-001'
            }
        }

        It 'includes SHA256 hash in URI' {
            Send-SEPMCommandGetFile -ComputerName 'FileTarget' -SHA256 'ABCDEF1234567890ABCDEF1234567890ABCDEF1234567890ABCDEF1234567890' -FilePath 'C:\Temp\malware.exe' -Source 'FILESYSTEM '

            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'POST' -and $Uri -match 'sha256=ABCDEF1234567890ABCDEF1234567890ABCDEF1234567890ABCDEF1234567890'
            }
        }

        It 'includes file_path and source in URI' {
            Send-SEPMCommandGetFile -ComputerName 'FileTarget' -SHA256 'ABCDEF1234567890ABCDEF1234567890ABCDEF1234567890ABCDEF1234567890' -FilePath 'C:\Windows\System32\suspicious.dll' -Source 'QUARANTINE'

            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'POST' -and $Uri -match 'file_path=' -and $Uri -match 'source=QUARANTINE'
            }
        }

        It 'returns the API response' {
            $result = Send-SEPMCommandGetFile -ComputerName 'FileTarget' -SHA256 'ABCDEF1234567890ABCDEF1234567890ABCDEF1234567890ABCDEF1234567890' -FilePath 'C:\Temp\malware.exe' -Source 'BOTH'

            $result | Should -Not -BeNullOrEmpty
            $result.command_id | Should -Be 'CMD-FILE-001'
        }
    }

    Context 'MD5Hash parameter set' {
        BeforeAll {
            $fakeSession = New-TestSession
            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }
            Mock Get-SEPComputers -ModuleName PSSymantecSEPM {
                return [PSCustomObject]@{ uniqueId = 'FILE-TARGET-002'; computerName = 'MD5Target' }
            }
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                return @{ command_id = 'CMD-FILE-MD5-001' }
            }
        }

        It 'includes MD5 hash in URI when using MD5Hash parameter set' {
            Send-SEPMCommandGetFile -ComputerName 'MD5Target' -MD5 'ABCDEF1234567890ABCDEF1234567890' -FilePath 'C:\Temp\test.bin'

            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'POST' -and $Uri -match 'md5=ABCDEF1234567890ABCDEF1234567890'
            }
        }
    }

    Context 'SHA1Hash parameter set' {
        BeforeAll {
            $fakeSession = New-TestSession
            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }
            Mock Get-SEPComputers -ModuleName PSSymantecSEPM {
                return [PSCustomObject]@{ uniqueId = 'FILE-TARGET-003'; computerName = 'SHA1Target' }
            }
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                return @{ command_id = 'CMD-FILE-SHA1-001' }
            }
        }

        It 'includes SHA1 hash in URI when using SHA1Hash parameter set' {
            Send-SEPMCommandGetFile -ComputerName 'SHA1Target' -SHA1 'ABCDEF1234567890ABCDEF1234567890ABCDEF12' -FilePath 'C:\Temp\binary.exe'

            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'POST' -and $Uri -match 'sha1=ABCDEF1234567890ABCDEF1234567890ABCDEF12'
            }
        }
    }
}
