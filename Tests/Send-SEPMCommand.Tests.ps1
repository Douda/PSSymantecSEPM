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
        It 'POSTs to the correct quarantine endpoint with computer_ids and no undo' {
            Send-SEPMCommand -Type Quarantine -ComputerName 'PC1'

            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'POST' -and $Uri -match '/command-queue/quarantine' -and $Uri -match 'computer_ids=ABC123' -and $Uri -notmatch 'undo='
            }
        }

        It 'includes undo=True in query params when -Undo switch is used' {
            Send-SEPMCommand -Type Quarantine -ComputerName 'PC1' -Undo

            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'POST' -and $Uri -match '/command-queue/quarantine' -and $Uri -match 'computer_ids=ABC123' -and $Uri -match 'undo=True'
            }
        }
    }

    Context 'runtime validation' {
        It 'rejects -FilePath with -Type ActiveScan' {
            { Send-SEPMCommand -Type ActiveScan -ComputerName 'PC1' -FilePath 'C:\x.exe' -ErrorAction Stop } |
                Should -Throw '-FilePath is only valid with -Type GetFile'
        }

        It 'rejects -Source with -Type ActiveScan' {
            { Send-SEPMCommand -Type ActiveScan -ComputerName 'PC1' -Source FILESYSTEM -ErrorAction Stop } |
                Should -Throw '-Source is only valid with -Type GetFile'
        }

        It 'rejects -SHA256 with -Type ActiveScan' {
            $hash = 'ABCDEF1234567890ABCDEF1234567890ABCDEF1234567890ABCDEF1234567890'
            { Send-SEPMCommand -Type ActiveScan -ComputerName 'PC1' -SHA256 $hash -ErrorAction Stop } |
                Should -Throw '-SHA256 is only valid with -Type ClearIronCache, GetFile'
        }

        It 'rejects -MD5 with -Type FullScan' {
            { Send-SEPMCommand -Type FullScan -ComputerName 'PC1' -MD5 'ABCDEF1234567890ABCDEF1234567890' -ErrorAction Stop } |
                Should -Throw '-MD5 is only valid with -Type ClearIronCache, GetFile'
        }

        It 'rejects -SHA1 with -Type Quarantine' {
            { Send-SEPMCommand -Type Quarantine -ComputerName 'PC1' -SHA1 'ABCDEF1234567890ABCDEF1234567890ABCDEF12' -ErrorAction Stop } |
                Should -Throw '-SHA1 is only valid with -Type ClearIronCache, GetFile'
        }
    }

    Context 'hash length validation' {
        It 'rejects SHA256 with 63 characters' {
            $shortHash = 'A' * 63
            { Send-SEPMCommand -Type GetFile -ComputerName 'PC1' -SHA256 $shortHash -ErrorAction Stop } |
                Should -Throw '-SHA256 must be exactly 64 characters, got 63'
        }

        It 'rejects SHA256 with 65 characters' {
            $longHash = 'A' * 65
            { Send-SEPMCommand -Type GetFile -ComputerName 'PC1' -SHA256 $longHash -ErrorAction Stop } |
                Should -Throw '-SHA256 must be exactly 64 characters, got 65'
        }

        It 'rejects MD5 with 31 characters' {
            $shortHash = 'A' * 31
            { Send-SEPMCommand -Type GetFile -ComputerName 'PC1' -MD5 $shortHash -ErrorAction Stop } |
                Should -Throw '-MD5 must be exactly 32 characters, got 31'
        }

        It 'rejects MD5 with 33 characters' {
            $longHash = 'A' * 33
            { Send-SEPMCommand -Type GetFile -ComputerName 'PC1' -MD5 $longHash -ErrorAction Stop } |
                Should -Throw '-MD5 must be exactly 32 characters, got 33'
        }

        It 'rejects SHA1 with 39 characters' {
            $shortHash = 'A' * 39
            { Send-SEPMCommand -Type GetFile -ComputerName 'PC1' -SHA1 $shortHash -ErrorAction Stop } |
                Should -Throw '-SHA1 must be exactly 40 characters, got 39'
        }

        It 'rejects SHA1 with 41 characters' {
            $longHash = 'A' * 41
            { Send-SEPMCommand -Type GetFile -ComputerName 'PC1' -SHA1 $longHash -ErrorAction Stop } |
                Should -Throw '-SHA1 must be exactly 40 characters, got 41'
        }

        It 'accepts valid SHA256 for ClearIronCache' {
            $hash = 'ABCDEF1234567890ABCDEF1234567890ABCDEF1234567890ABCDEF1234567890'
            Send-SEPMCommand -Type ClearIronCache -ComputerName 'PC1' -SHA256 $hash

            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'POST' -and $Body -match 'hashType.*sha256'
            }
        }

        It 'accepts valid MD5 for ClearIronCache with correct body shape' {
            $hash = 'ABCDEF1234567890ABCDEF1234567890'
            Send-SEPMCommand -Type ClearIronCache -ComputerName 'PC1' -MD5 $hash

            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'POST' -and $Body -match 'hashType.*md5' -and $Body -match "data.*$hash"
            }
        }

        It 'accepts valid SHA1 for ClearIronCache with correct body shape' {
            $hash = 'ABCDEF1234567890ABCDEF1234567890ABCDEF12'
            Send-SEPMCommand -Type ClearIronCache -ComputerName 'PC1' -SHA1 $hash

            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'POST' -and $Body -match 'hashType.*sha1' -and $Body -match "data.*$hash"
            }
        }
    }

    Context 'GetFile dispatch' {
        It 'includes sha256 hash in query params' {
            $hash = 'ABCDEF1234567890ABCDEF1234567890ABCDEF1234567890ABCDEF1234567890'
            Send-SEPMCommand -Type GetFile -ComputerName 'PC1' -SHA256 $hash

            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'POST' -and $Uri -match '/command-queue/files' -and $Uri -match 'sha256=ABCDEF1234567890ABCDEF1234567890ABCDEF1234567890ABCDEF1234567890'
            }
        }

        It 'includes file_path in query params' {
            Send-SEPMCommand -Type GetFile -ComputerName 'PC1' -FilePath 'C:\Temp\malware.exe'

            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'POST' -and $Uri -match '/command-queue/files' -and $Uri -match 'file_path=C%3A%5CTemp%5Cmalware.exe'
            }
        }

        It 'includes source=QUARANTINE in query params' {
            Send-SEPMCommand -Type GetFile -ComputerName 'PC1' -Source QUARANTINE

            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'POST' -and $Uri -match '/command-queue/files' -and $Uri -match 'source=QUARANTINE'
            }
        }

        It 'rejects invalid Source value with validation error' {
            { Send-SEPMCommand -Type GetFile -ComputerName 'PC1' -Source BOGUS -ErrorAction Stop } | Should -Throw '-Source must be one of: FILESYSTEM, QUARANTINE, BOTH'
        }
    }
}
