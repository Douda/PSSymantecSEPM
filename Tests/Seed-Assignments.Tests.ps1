[CmdletBinding()]
param()

Describe 'Seed-SEPMData -Categories Assignments' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment

        $script:SeedScriptPath = Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath 'Scripts/Seed-SEPMData.ps1'
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context '-Categories Assignments dispatch' {
        BeforeAll {
            $fakeSession = New-TestSession -SkipCert
            $realModule = Get-Module PSSymantecSEPM

            Mock Import-Module { return $realModule }
            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }

            # Mock all prerequisite seed functions (they rung before assignments in real usage)
            # The state tables need to be populated
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                param($Method, $Uri, $Session, $Body, $ContentType)
            }
        }

        It 'dispatches to Invoke-SeedAssignments and reports count of assignments' {
            $output = & $script:SeedScriptPath -Categories Assignments

            $output | Should -Not -BeNullOrEmpty
            ($output -match '=== Seeding Assignments ===') | Should -Not -BeNullOrEmpty
            ($output -match 'Assignments created:') | Should -Not -BeNullOrEmpty
        }
    }
}
