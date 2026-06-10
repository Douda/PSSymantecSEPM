[CmdletBinding()]
param()

Describe 'UpgradePolicies seed data file' {
    BeforeAll {
        $script:SeedDir = Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath 'Source/Seed'
        $script:DataFile = Join-Path -Path $script:SeedDir -ChildPath 'UpgradePolicies.psd1'
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
        It 'has 3 policies' {
            $script:Data.Policies.Count | Should -Be 3
        }

        It 'contains Zero-Day Upgrade' {
            $names = $script:Data.Policies.Name
            $names | Should -Contain 'Zero-Day Upgrade'
        }

        It 'contains Weekend Upgrade' {
            $names = $script:Data.Policies.Name
            $names | Should -Contain 'Weekend Upgrade'
        }

        It 'contains Manual Upgrade' {
            $names = $script:Data.Policies.Name
            $names | Should -Contain 'Manual Upgrade'
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

    Context 'Zero-Day Upgrade' {
        BeforeAll {
            $script:ZeroDay = $script:Data.Policies | Where-Object { $_.Name -eq 'Zero-Day Upgrade' }
        }

        It 'has release_delay_days=0' {
            $script:ZeroDay.Configuration.release_delay_days | Should -Be 0
        }

        It 'has all 7 days enabled' {
            $daily = $script:ZeroDay.Configuration.schedule.daily
            $daily.monday    | Should -BeTrue
            $daily.tuesday   | Should -BeTrue
            $daily.wednesday | Should -BeTrue
            $daily.thursday  | Should -BeTrue
            $daily.friday    | Should -BeTrue
            $daily.saturday  | Should -BeTrue
            $daily.sunday    | Should -BeTrue
        }

        It 'has time_window=86400' {
            $script:ZeroDay.Configuration.schedule.time_window | Should -Be 86400
        }

        It 'has retry_enabled=true' {
            $script:ZeroDay.Configuration.schedule.retry_enabled | Should -BeTrue
        }
    }

    Context 'Weekend Upgrade' {
        BeforeAll {
            $script:Weekend = $script:Data.Policies | Where-Object { $_.Name -eq 'Weekend Upgrade' }
        }

        It 'has release_delay_days=7' {
            $script:Weekend.Configuration.release_delay_days | Should -Be 7
        }

        It 'has only Saturday+Sunday enabled' {
            $daily = $script:Weekend.Configuration.schedule.daily
            $daily.monday    | Should -BeFalse
            $daily.tuesday   | Should -BeFalse
            $daily.wednesday | Should -BeFalse
            $daily.thursday  | Should -BeFalse
            $daily.friday    | Should -BeFalse
            $daily.saturday  | Should -BeTrue
            $daily.sunday    | Should -BeTrue
        }

        It 'has time_window=14400' {
            $script:Weekend.Configuration.schedule.time_window | Should -Be 14400
        }

        It 'has retry_enabled=true' {
            $script:Weekend.Configuration.schedule.retry_enabled | Should -BeTrue
        }
    }

    Context 'Manual Upgrade' {
        BeforeAll {
            $script:Manual = $script:Data.Policies | Where-Object { $_.Name -eq 'Manual Upgrade' }
        }

        It 'has enabled=false' {
            $script:Manual.Enabled | Should -BeFalse
        }

        It 'has all days disabled' {
            $daily = $script:Manual.Configuration.schedule.daily
            $daily.monday    | Should -BeFalse
            $daily.tuesday   | Should -BeFalse
            $daily.wednesday | Should -BeFalse
            $daily.thursday  | Should -BeFalse
            $daily.friday    | Should -BeFalse
            $daily.saturday  | Should -BeFalse
            $daily.sunday    | Should -BeFalse
        }
    }

    Context 'Schedule structure' {
        It 'every policy has daily sub-object with time string' {
            foreach ($p in $script:Data.Policies) {
                $p.Configuration.schedule.daily | Should -Not -BeNullOrEmpty
                $p.Configuration.schedule.daily.time | Should -Not -BeNullOrEmpty
            }
        }

        It 'every policy has end_time string' {
            foreach ($p in $script:Data.Policies) {
                $p.Configuration.schedule.end_time | Should -Not -BeNullOrEmpty
            }
        }

        It 'every policy has retry_enabled boolean' {
            foreach ($p in $script:Data.Policies) {
                $p.Configuration.schedule.retry_enabled -is [bool] | Should -BeTrue
            }
        }

        It 'every policy has time_window integer in valid range' {
            foreach ($p in $script:Data.Policies) {
                $tw = $p.Configuration.schedule.time_window
                $tw -is [int] | Should -BeTrue
                $tw | Should -BeGreaterOrEqual 0
                $tw | Should -BeLessOrEqual 2592000
            }
        }

        It 'every policy has release_delay_days in valid range' {
            foreach ($p in $script:Data.Policies) {
                $rdd = $p.Configuration.release_delay_days
                $rdd -is [int] | Should -BeTrue
                $rdd | Should -BeGreaterOrEqual 0
                $rdd | Should -BeLessOrEqual 45
            }
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
