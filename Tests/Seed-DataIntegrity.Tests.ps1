[CmdletBinding()]
param()

BeforeAll {
    $script:SeedRoot = (Resolve-Path "$PSScriptRoot/../Source/Seed").Path
}

Describe 'Seed data integrity' {

    Context 'file discovery' {
        It 'discovers all .psd1 files under Source/Seed/' {
            $files = Get-ChildItem -Path $script:SeedRoot -Filter '*.psd1'
            $files | Should -Not -BeNullOrEmpty
            $files.Count | Should -BeGreaterThan 0
        }
    }

    Context 'cross-cutting checks' {

        BeforeAll {
            $script:SeedFiles = Get-ChildItem -Path $script:SeedRoot -Filter '*.psd1'
        }

        It 'has no UTF-8 BOM in any file' {
            $violations = @()
            foreach ($file in $script:SeedFiles) {
                $raw = [System.IO.File]::ReadAllBytes($file.FullName)
                if ($raw.Length -ge 3 -and $raw[0] -eq 0xEF -and $raw[1] -eq 0xBB -and $raw[2] -eq 0xBF) {
                    $violations += $file.Name
                }
            }
            $violations | Should -BeNullOrEmpty -Because 'files must not have UTF-8 BOM'
        }

        It 'has valid @{ preamble as first line' {
            $violations = @()
            foreach ($file in $script:SeedFiles) {
                $firstLine = Get-Content -Path $file.FullName -TotalCount 1
                if ($firstLine -notmatch '^@\{') {
                    $violations += $file.Name
                }
            }
            $violations | Should -BeNullOrEmpty -Because 'files must start with @{'
        }

        It 'has no hardcoded ID strings' {
            $violations = @()
            foreach ($file in $script:SeedFiles) {
                $content = Get-Content -Path $file.FullName -Raw
                if ($content -match 'id\s*=\s*[''"]') {
                    $violations += $file.Name
                }
            }
            $violations | Should -BeNullOrEmpty -Because 'files must not contain hardcoded id="..." patterns'
        }
    }
}
