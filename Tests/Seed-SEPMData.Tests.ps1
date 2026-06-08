[CmdletBinding()]
param()

Describe 'Seed-SEPMData' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment

        InModuleScope PSSymantecSEPM {
            $script:configurationFilePath = Join-Path -Path 'TestDrive:' -ChildPath 'config.json'
            $script:credentialsFilePath   = Join-Path -Path 'TestDrive:' -ChildPath 'creds.xml'
            $script:accessTokenFilePath   = Join-Path -Path 'TestDrive:' -ChildPath 'token.xml'
        }

        $script:SeedScriptPath = Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath 'Scripts/Seed-SEPMData.ps1'
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context '-Categories Test (tracer bullet)' {
        BeforeAll {
            $fakeSession = New-TestSession -SkipCert
            $realModule = Get-Module PSSymantecSEPM

            Mock Import-Module { return $realModule }
            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }
        }

        It 'prints "Framework ready" and produces no errors' {
            $output = & $script:SeedScriptPath -Categories Test

            $output | Should -Not -BeNullOrEmpty
            ($output -match 'Framework ready') | Should -Not -BeNullOrEmpty

            $errors = $output | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] }
            $errors | Should -BeNullOrEmpty
        }
    }

    Context 'No parameters (defaults to all categories)' {
        BeforeAll {
            $fakeSession = New-TestSession -SkipCert
            $realModule = Get-Module PSSymantecSEPM

            Mock Import-Module { return $realModule }
            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }
        }

        It 'prints "No categories implemented yet"' {
            $output = & $script:SeedScriptPath

            $output | Should -Not -BeNullOrEmpty
            ($output -match 'No categories implemented yet') | Should -Not -BeNullOrEmpty
        }
    }

    Context '-Force flag' {
        BeforeAll {
            $fakeSession = New-TestSession -SkipCert
            $realModule = Get-Module PSSymantecSEPM

            Mock Import-Module { return $realModule }
            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }
        }

        It 'stores Force in State when -Force is passed' {
            $output = & $script:SeedScriptPath -Categories Test -Force

            ($output -match 'Framework ready') | Should -Not -BeNullOrEmpty
            $output -match 'Force: True' | Should -BeTrue
        }

        It 'does not store Force when -Force is absent' {
            $output = & $script:SeedScriptPath -Categories Test

            ($output -match 'Framework ready') | Should -Not -BeNullOrEmpty
            $output -match 'Force: False' | Should -BeTrue
        }
    }
}
