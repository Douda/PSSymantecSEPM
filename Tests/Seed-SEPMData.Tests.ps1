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

    Context '-Categories Groups dispatch' {
        BeforeAll {
            $fakeSession = New-TestSession -SkipCert
            $realModule = Get-Module PSSymantecSEPM

            Mock Import-Module { return $realModule }
            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }
            Mock Get-SEPMGroups {
                return @(
                    [PSCustomObject]@{ id = 'mc-id'; name = 'My Company'; fullPathName = 'My Company' },
                    [PSCustomObject]@{ id = 'def-id'; name = 'Default Group'; fullPathName = 'My Company\Default Group' }
                )
            }
            Mock New-SEPMGroup {
                return @{ id = 'fake-id'; name = $GroupName; fullPathName = "$ParentGroup\$GroupName" }
            }
            Mock Invoke-SepmApi { param($Method, $Uri, $Session, $Body, $ContentType) }
        }

        It 'dispatches to Invoke-SeedGroups and reports count' {
            $output = & $script:SeedScriptPath -Categories Groups

            $output | Should -Not -BeNullOrEmpty
            ($output -match '=== Seeding Groups ===') | Should -Not -BeNullOrEmpty
            ($output -match 'Groups seeded:') | Should -Not -BeNullOrEmpty
        }
    }

    Context '-Categories ExceptionsPolicies dispatch' {
        BeforeAll {
            $fakeSession = New-TestSession -SkipCert
            $realModule = Get-Module PSSymantecSEPM

            Mock Import-Module { return $realModule }
            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }

            # Simulate GET returning 4 existing policies (idempotent skip)
            # Must be module-scoped because _InvokeApi calls via & $State.Module
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                if ($Method -eq 'GET') {
                    return @{
                        content = @(
                            @{ name = 'Standard Workstation Exceptions'; id = 'id-1' }
                            @{ name = 'Server Exceptions'; id = 'id-2' }
                            @{ name = 'Developer Exceptions'; id = 'id-3' }
                            @{ name = 'Emergency Disabled'; id = 'id-4' }
                        )
                    }
                }
                return $null
            }
        }

        It 'dispatches to Invoke-SeedExceptionsPolicies and reports count' {
            $output = & $script:SeedScriptPath -Categories ExceptionsPolicies

            $output | Should -Not -BeNullOrEmpty
            ($output -match '=== Seeding Exceptions Policies ===') | Should -Not -BeNullOrEmpty
            ($output -match 'Exceptions policies seeded: 4') | Should -Not -BeNullOrEmpty
        }
    }
}
