[CmdletBinding()]
param()

Describe 'ExceptionsPolicies seed data file' {
    BeforeAll {
        $script:SeedDir = Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath 'Source/Seed'
        $script:DataFile = Join-Path -Path $script:SeedDir -ChildPath 'ExceptionsPolicies.psd1'
        $script:Data = Import-PowerShellDataFile -Path $script:DataFile -ErrorAction Stop
    }

    Context 'File structure' {
        It 'imports without errors via Import-PowerShellDataFile' {
            $script:Data | Should -Not -BeNullOrEmpty
        }

        It 'contains a Policies key' {
            $script:Data.ContainsKey('Policies') | Should -BeTrue
            $script:Data.Policies | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Policy count and names' {
        It 'has 4 policies' {
            $script:Data.Policies.Count | Should -Be 4
        }

        It 'contains Standard Workstation Exceptions' {
            $names = $script:Data.Policies.Name
            $names | Should -Contain 'Standard Workstation Exceptions'
        }

        It 'contains Server Exceptions' {
            $names = $script:Data.Policies.Name
            $names | Should -Contain 'Server Exceptions'
        }

        It 'contains Developer Exceptions' {
            $names = $script:Data.Policies.Name
            $names | Should -Contain 'Developer Exceptions'
        }

        It 'contains Emergency Disabled' {
            $names = $script:Data.Policies.Name
            $names | Should -Contain 'Emergency Disabled'
        }
    }

    Context 'Every policy has required fields' {
        It 'all policies have Name' {
            foreach ($p in $script:Data.Policies) {
                $p.Name | Should -Not -BeNullOrEmpty
            }
        }

        It 'all policies have Description' {
            foreach ($p in $script:Data.Policies) {
                $p.Description | Should -Not -BeNullOrEmpty
            }
        }

        It 'all policies have Enabled (bool)' {
            foreach ($p in $script:Data.Policies) {
                $p.Enabled -is [bool] | Should -BeTrue
            }
        }

        It 'all policies have Configuration' {
            foreach ($p in $script:Data.Policies) {
                $p.Configuration | Should -Not -BeNullOrEmpty
            }
        }

        It 'policy names are unique' {
            $names = $script:Data.Policies.Name
            ($names | Select-Object -Unique).Count | Should -Be $names.Count
        }
    }

    Context 'Standard Workstation Exceptions' {
        BeforeAll {
            $script:Standard = $script:Data.Policies | Where-Object { $_.Name -eq 'Standard Workstation Exceptions' }
        }

        It 'is enabled' {
            $script:Standard.Enabled | Should -BeTrue
        }

        It 'has at least 3 file exceptions' {
            $script:Standard.Configuration.files.Count | Should -BeGreaterOrEqual 3
        }

        It 'has at least 2 folder exceptions' {
            $script:Standard.Configuration.directories.Count | Should -BeGreaterOrEqual 2
        }

        It 'has at least 1 extension exception' {
            $script:Standard.Configuration.extension_list.extensions.Count | Should -BeGreaterOrEqual 1
        }

        It 'file exceptions have path and pathvariable' {
            foreach ($f in $script:Standard.Configuration.files) {
                $f.path | Should -Not -BeNullOrEmpty
                $f.pathvariable | Should -Not -BeNullOrEmpty
            }
        }

        It 'directory exceptions have directory and pathvariable' {
            foreach ($d in $script:Standard.Configuration.directories) {
                $d.directory | Should -Not -BeNullOrEmpty
                $d.pathvariable | Should -Not -BeNullOrEmpty
            }
        }

        It 'extension_list has extensions array' {
            $script:Standard.Configuration.extension_list.extensions | Should -Not -BeNullOrEmpty
            $script:Standard.Configuration.extension_list.extensions.Count | Should -BeGreaterOrEqual 1
        }
    }

    Context 'Server Exceptions' {
        BeforeAll {
            $script:Server = $script:Data.Policies | Where-Object { $_.Name -eq 'Server Exceptions' }
        }

        It 'is enabled' {
            $script:Server.Enabled | Should -BeTrue
        }

        It 'has tamper protection rules' {
            $script:Server.Configuration.tamper_files | Should -Not -BeNullOrEmpty
            $script:Server.Configuration.tamper_files.Count | Should -BeGreaterOrEqual 1
        }

        It 'has no file exceptions' {
            $script:Server.Configuration.ContainsKey('files') | Should -BeFalse
        }

        It 'has no folder exceptions' {
            $script:Server.Configuration.ContainsKey('directories') | Should -BeFalse
        }

        It 'has no extension exceptions' {
            $script:Server.Configuration.ContainsKey('extension_list') | Should -BeFalse
        }

        It 'tamper rules have path and pathvariable' {
            foreach ($t in $script:Server.Configuration.tamper_files) {
                $t.path | Should -Not -BeNullOrEmpty
                $t.pathvariable | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context 'Developer Exceptions' {
        BeforeAll {
            $script:Dev = $script:Data.Policies | Where-Object { $_.Name -eq 'Developer Exceptions' }
        }

        It 'is enabled' {
            $script:Dev.Enabled | Should -BeTrue
        }

        It 'has broad folder exceptions (scantype=All, recursive)' {
            $allDirs = $script:Dev.Configuration.directories | Where-Object { $_.scantype -eq 'All' -and $_.recursive -eq $true }
            $allDirs.Count | Should -BeGreaterOrEqual 2
        }

        It 'has extension exceptions' {
            $script:Dev.Configuration.extension_list.extensions.Count | Should -BeGreaterOrEqual 1
        }
    }

    Context 'Emergency Disabled' {
        BeforeAll {
            $script:Emergency = $script:Data.Policies | Where-Object { $_.Name -eq 'Emergency Disabled' }
        }

        It 'has enabled=false' {
            $script:Emergency.Enabled | Should -BeFalse
        }

        It 'has same file count as Standard Workstation' {
            $script:Emergency.Configuration.files.Count | Should -Be $script:Standard.Configuration.files.Count
        }

        It 'has same directory count as Standard Workstation' {
            $script:Emergency.Configuration.directories.Count | Should -Be $script:Standard.Configuration.directories.Count
        }

        It 'has same extension count as Standard Workstation' {
            $script:Emergency.Configuration.extension_list.extensions.Count | Should -Be $script:Standard.Configuration.extension_list.extensions.Count
        }
    }

    Context 'File encoding' {
        It 'has no BOM (PS7-compatible)' {
            $bytes = [System.IO.File]::ReadAllBytes($script:DataFile)
            $hasBOM = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
            $hasBOM | Should -BeFalse -Because 'PS7 .psd1 files must not have UTF-8 BOM'
        }

        It 'starts with @{ (valid .psd1 syntax)' {
            $firstLine = Get-Content -Path $script:DataFile -First 1
            $firstLine.TrimStart() | Should -Match '^@\{'
        }
    }

    Context 'No hardcoded IDs' {
        It 'no node has hardcoded IDs' {
            $text = Get-Content -Path $script:DataFile -Raw
            $text -match '\bid\s*=' | Should -BeFalse -Because 'policies must not have hardcoded IDs'
        }
    }
}
