[CmdletBinding()]
param()

Describe 'Restore-SEPMConfiguration' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment
        $script:ConfigPath = Join-Path -Path 'TestDrive:' -ChildPath 'config.json'
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context 'Restoring from a valid configuration file' {
        It 'Copies the source file to the module config path' {
            $sourcePath = Join-Path -Path 'TestDrive:' -ChildPath 'sources/valid-config.json'
            $null = New-Item -Path (Split-Path -Path $sourcePath -Parent) -ItemType Directory -Force
            $configJson = @{
                ServerAddress = 'restored-server'
                port          = '8446'
                domain        = 'Default'
            } | ConvertTo-Json
            Set-Content -Path $sourcePath -Value $configJson

            Restore-SEPMConfiguration -Path $sourcePath

            Test-Path -Path $script:ConfigPath -PathType Leaf | Should -Be $true
            $content = Get-Content -Path $script:ConfigPath -Raw | ConvertFrom-Json
            $content.ServerAddress | Should -Be 'restored-server'
            $content.port | Should -Not -BeNullOrEmpty
        }

        It 'Persists restored ServerAddress to disk' {
            $sourcePath = Join-Path -Path 'TestDrive:' -ChildPath 'sources/config-update.json'
            $configJson = @{
                ServerAddress = 'module-update'
                port          = '9443'
            } | ConvertTo-Json
            Set-Content -Path $sourcePath -Value $configJson

            Restore-SEPMConfiguration -Path $sourcePath

            $content = Get-Content -Path $script:ConfigPath -Raw | ConvertFrom-Json
            $content.ServerAddress | Should -Be 'module-update'
        }

        It 'Copies existing file content correctly' {
            $sourcePath = Join-Path -Path 'TestDrive:' -ChildPath 'sources/content-check.json'
            $configJson = @{
                ServerAddress = 'exact-match'
                port          = '1234'
                domain        = 'TestDomain'
            } | ConvertTo-Json
            Set-Content -Path $sourcePath -Value $configJson

            Restore-SEPMConfiguration -Path $sourcePath

            $rawContent = Get-Content -Path $script:ConfigPath -Raw
            $content = $rawContent | ConvertFrom-Json
            $content.ServerAddress | Should -Be 'exact-match'
            $content.port | Should -Be '1234'
            $content.domain | Should -Be 'TestDomain'
        }
    }

    Context 'Parameter validation' {
        It 'Throws for a non-existent file path' {
            $nonExistentPath = Join-Path -Path 'TestDrive:' -ChildPath 'sources/does-not-exist.json'

            { Restore-SEPMConfiguration -Path $nonExistentPath } |
                Should -Throw -ErrorId 'ParameterArgumentValidationError,Restore-SEPMConfiguration'
        }
    }
}
