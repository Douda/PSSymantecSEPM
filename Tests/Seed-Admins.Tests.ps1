[CmdletBinding()]
param()

Describe 'Admins seed data file' {
    BeforeAll {
        $script:SeedDir = Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath 'Source/Seed'
        $script:AdminsFile = Join-Path -Path $script:SeedDir -ChildPath 'Admins.psd1'
        $script:Data = Import-PowerShellDataFile -Path $script:AdminsFile -ErrorAction Stop
    }

    Context 'File structure' {
        It 'imports without errors via Import-PowerShellDataFile' {
            $script:Data | Should -Not -BeNullOrEmpty
        }

        It 'contains an Admins key' {
            $script:Data.ContainsKey('Admins') | Should -BeTrue
            $script:Data.Admins | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Entry count' {
        It 'has 6 admin entries' {
            $script:Data.Admins.Count | Should -Be 6
        }
    }

    Context 'Required fields' {
        BeforeAll {
            $script:RequiredFields = @('loginName', 'fullName', 'adminType', 'emailAddress', 'password')
        }

        It 'every entry has all required fields' {
            foreach ($entry in $script:Data.Admins) {
                foreach ($field in $script:RequiredFields) {
                    $entry.ContainsKey($field) | Should -BeTrue -Because "'$($entry.loginName)' must have field '$field'"
                    $entry[$field] | Should -Not -BeNullOrEmpty -Because "'$($entry.loginName)' field '$field' must not be empty"
                }
            }
        }
    }

    Context 'Specific entries' {
        It 'jdoe is system admin (type 1)' {
            $admin = $script:Data.Admins | Where-Object { $_.loginName -eq 'jdoe' }
            $admin | Should -Not -BeNullOrEmpty
            $admin.fullName | Should -Be 'IT Security Lead'
            $admin.adminType | Should -Be 1
        }

        It 'soc-automation is domain admin (type 2)' {
            $admin = $script:Data.Admins | Where-Object { $_.loginName -eq 'soc-automation' }
            $admin | Should -Not -BeNullOrEmpty
            $admin.fullName | Should -Be 'SIEM and SOAR integration'
            $admin.adminType | Should -Be 2
        }

        It 'helpdesk-lead is domain admin (type 2)' {
            $admin = $script:Data.Admins | Where-Object { $_.loginName -eq 'helpdesk-lead' }
            $admin | Should -Not -BeNullOrEmpty
            $admin.fullName | Should -Be 'Desktop support'
            $admin.adminType | Should -Be 2
        }

        It 'emea-admin is domain admin (type 2)' {
            $admin = $script:Data.Admins | Where-Object { $_.loginName -eq 'emea-admin' }
            $admin | Should -Not -BeNullOrEmpty
            $admin.fullName | Should -Be 'Regional admin'
            $admin.adminType | Should -Be 2
        }

        It 'ops-readonly is limited admin (type 3)' {
            $admin = $script:Data.Admins | Where-Object { $_.loginName -eq 'ops-readonly' }
            $admin | Should -Not -BeNullOrEmpty
            $admin.fullName | Should -Be 'NOC monitoring'
            $admin.adminType | Should -Be 3
        }

        It 'sec-auditor is limited admin (type 3)' {
            $admin = $script:Data.Admins | Where-Object { $_.loginName -eq 'sec-auditor' }
            $admin | Should -Not -BeNullOrEmpty
            $admin.fullName | Should -Be 'Compliance audits'
            $admin.adminType | Should -Be 3
        }
    }

    Context 'adminType values' {
        It 'all adminType values are valid (1, 2, or 3)' {
            foreach ($entry in $script:Data.Admins) {
                $entry.adminType -in @(1, 2, 3) | Should -BeTrue -Because "'$($entry.loginName)' has invalid adminType $($entry.adminType)"
            }
        }
    }

    Context 'Password' {
        It 'all entries share the same password' {
            $passwords = $script:Data.Admins | ForEach-Object { $_.password } | Select-Object -Unique
            $passwords.Count | Should -Be 1
        }
    }

    Context 'No hardcoded IDs' {
        It 'no entry has hardcoded IDs' {
            $text = Get-Content -Path $script:AdminsFile -Raw
            $text -match '\bid\s*=' | Should -BeFalse -Because 'entries must not have hardcoded IDs'
        }
    }

    Context 'File encoding' {
        It 'has no BOM (PS7-compatible)' {
            $bytes = [System.IO.File]::ReadAllBytes($script:AdminsFile)
            $hasBOM = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
            $hasBOM | Should -BeFalse -Because 'PS7 .psd1 files must not have UTF-8 BOM'
        }

        It 'starts with @{ (valid .psd1 syntax)' {
            $firstLine = Get-Content -Path $script:AdminsFile -First 1
            $firstLine.TrimStart() | Should -Match '^@\{'
        }
    }
}
