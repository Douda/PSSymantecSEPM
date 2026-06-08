[CmdletBinding()]
param()

Describe 'MEMPolicies seed data file' {
    BeforeAll {
        $script:SeedDir = Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath 'Source/Seed'
        $script:DataFile = Join-Path -Path $script:SeedDir -ChildPath 'MEMPolicies.psd1'
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

        It 'contains Standard MEM' {
            $names = $script:Data.Policies.Name
            $names | Should -Contain 'Standard MEM'
        }

        It 'contains Advanced MEM' {
            $names = $script:Data.Policies.Name
            $names | Should -Contain 'Advanced MEM'
        }

        It 'contains Java-Only MEM' {
            $names = $script:Data.Policies.Name
            $names | Should -Contain 'Java-Only MEM'
        }

        It 'contains Audit MEM' {
            $names = $script:Data.Policies.Name
            $names | Should -Contain 'Audit MEM'
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

    Context 'Standard MEM' {
        BeforeAll {
            $script:Standard = $script:Data.Policies | Where-Object { $_.Name -eq 'Standard MEM' }
        }

        It 'has basic enabled=true' {
            $script:Standard.Configuration.enabled | Should -BeTrue
        }

        It 'has enableadvanced=false' {
            $script:Standard.Configuration.enableadvanced | Should -BeFalse
        }

        It 'has enablejavaprotection=true' {
            $script:Standard.Configuration.enablejavaprotection | Should -BeTrue
        }

        It 'has no custom rules' {
            $script:Standard.Configuration.customrules | Should -BeNullOrEmpty
        }

        It 'has no global technique overrides' {
            $script:Standard.Configuration.globaltechniqueoverrides | Should -BeNullOrEmpty
        }
    }

    Context 'Advanced MEM' {
        BeforeAll {
            $script:Advanced = $script:Data.Policies | Where-Object { $_.Name -eq 'Advanced MEM' }
        }

        It 'has basic enabled=true' {
            $script:Advanced.Configuration.enabled | Should -BeTrue
        }

        It 'has enableadvanced=true' {
            $script:Advanced.Configuration.enableadvanced | Should -BeTrue
        }

        It 'has enablejavaprotection=true' {
            $script:Advanced.Configuration.enablejavaprotection | Should -BeTrue
        }

        It 'has at least 2 custom protected application paths' {
            $script:Advanced.Configuration.customrules.Count | Should -BeGreaterOrEqual 2
        }

        It 'custom rules have path field' {
            foreach ($rule in $script:Advanced.Configuration.customrules) {
                $rule.path | Should -Not -BeNullOrEmpty
            }
        }

        It 'has global technique overrides with BLOCK actions' {
            $overrides = $script:Advanced.Configuration.globaltechniqueoverrides
            $overrides | Should -Not -BeNullOrEmpty
            $overrides.Count | Should -BeGreaterOrEqual 1
            foreach ($o in $overrides) {
                if ($o.ContainsKey('action')) {
                    $o.action | Should -Be 'BLOCK'
                }
            }
        }

        It 'global technique overrides have id and name' {
            foreach ($o in $script:Advanced.Configuration.globaltechniqueoverrides) {
                $o.id | Should -Not -BeNullOrEmpty
                $o.name | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context 'Java-Only MEM' {
        BeforeAll {
            $script:JavaOnly = $script:Data.Policies | Where-Object { $_.Name -eq 'Java-Only MEM' }
        }

        It 'has basic enabled=false' {
            $script:JavaOnly.Configuration.enabled | Should -BeFalse
        }

        It 'has enableadvanced=false' {
            $script:JavaOnly.Configuration.enableadvanced | Should -BeFalse
        }

        It 'has enablejavaprotection=true' {
            $script:JavaOnly.Configuration.enablejavaprotection | Should -BeTrue
        }
    }

    Context 'Audit MEM' {
        BeforeAll {
            $script:Audit = $script:Data.Policies | Where-Object { $_.Name -eq 'Audit MEM' }
        }

        It 'has basic enabled=true' {
            $script:Audit.Configuration.enabled | Should -BeTrue
        }

        It 'has globalauditmodeoverride=true' {
            $script:Audit.Configuration.globalauditmodeoverride | Should -BeTrue
        }

        It 'has no custom rules' {
            $script:Audit.Configuration.customrules | Should -BeNullOrEmpty
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
            $text -match "\bid\s*=\s*['`"]" | Should -BeFalse -Because 'policies must not have hardcoded IDs (quoted string IDs only; numeric technique IDs are OK)'
        }
    }
}
