[CmdletBinding()]
param()

Describe 'TDADPolicies seed data file' {
    BeforeAll {
        $script:SeedDir = Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath 'Source/Seed'
        $script:DataFile = Join-Path -Path $script:SeedDir -ChildPath 'TDADPolicies.psd1'
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
        It 'has 2 policies' {
            $script:Data.Policies.Count | Should -Be 2
        }

        It 'contains TDAD Enabled' {
            $names = $script:Data.Policies.Name
            $names | Should -Contain 'TDAD Enabled'
        }

        It 'contains TDAD Disabled' {
            $names = $script:Data.Policies.Name
            $names | Should -Contain 'TDAD Disabled'
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

        It 'all policies have configuration.enabled (bool)' {
            foreach ($p in $script:Data.Policies) {
                $p.Configuration.enabled -is [bool] | Should -BeTrue
            }
        }

        It 'all policies have configuration.ad_domains (array)' {
            foreach ($p in $script:Data.Policies) {
                $p.Configuration.ad_domains -is [array] | Should -BeTrue
            }
        }

        It 'policy names are unique' {
            $names = $script:Data.Policies.Name
            ($names | Select-Object -Unique).Count | Should -Be $names.Count
        }
    }

    Context 'TDAD Enabled' {
        BeforeAll {
            $script:Enabled = $script:Data.Policies | Where-Object { $_.Name -eq 'TDAD Enabled' }
        }

        It 'has Enabled=true' {
            $script:Enabled.Enabled | Should -BeTrue
        }

        It 'has configuration.enabled=true' {
            $script:Enabled.Configuration.enabled | Should -BeTrue
        }

        It 'has empty ad_domains array' {
            $script:Enabled.Configuration.ad_domains.Count | Should -Be 0
        }
    }

    Context 'TDAD Disabled' {
        BeforeAll {
            $script:Disabled = $script:Data.Policies | Where-Object { $_.Name -eq 'TDAD Disabled' }
        }

        It 'has Enabled=false' {
            $script:Disabled.Enabled | Should -BeFalse
        }

        It 'has configuration.enabled=false' {
            $script:Disabled.Configuration.enabled | Should -BeFalse
        }

        It 'has empty ad_domains array' {
            $script:Disabled.Configuration.ad_domains.Count | Should -Be 0
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
            $text -match "\bid\s*=\s*['`"]" | Should -BeFalse -Because 'policies must not have hardcoded IDs'
        }
    }
}
