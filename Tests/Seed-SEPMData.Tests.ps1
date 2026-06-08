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

    Context '-Categories MEMPolicies dispatch' {
        BeforeAll {
            $fakeSession = New-TestSession -SkipCert
            $realModule = Get-Module PSSymantecSEPM

            Mock Import-Module { return $realModule }
            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }

            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                if ($Method -eq 'GET') {
                    return @{
                        content = @(
                            @{ name = 'Standard MEM'; id = 'id-1' }
                            @{ name = 'Advanced MEM'; id = 'id-2' }
                            @{ name = 'Java-Only MEM'; id = 'id-3' }
                            @{ name = 'Audit MEM'; id = 'id-4' }
                        )
                    }
                }
                return $null
            }
        }

        It 'dispatches to Invoke-SeedMEMPolicies and reports count' {
            $output = & $script:SeedScriptPath -Categories MEMPolicies

            $output | Should -Not -BeNullOrEmpty
            ($output -match '=== Seeding MEM Policies ===') | Should -Not -BeNullOrEmpty
            ($output -match 'MEM policies seeded: 4') | Should -Not -BeNullOrEmpty
        }
    }

    Context '-Categories UpgradePolicies dispatch' {
        BeforeAll {
            $fakeSession = New-TestSession -SkipCert
            $realModule = Get-Module PSSymantecSEPM

            Mock Import-Module { return $realModule }
            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }

            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                if ($Method -eq 'GET') {
                    return @{
                        content = @(
                            @{ name = 'Zero-Day Upgrade'; id = 'id-zd' }
                            @{ name = 'Weekend Upgrade'; id = 'id-we' }
                            @{ name = 'Manual Upgrade'; id = 'id-mu' }
                        )
                    }
                }
                return $null
            }
        }

        It 'dispatches to Invoke-SeedUpgradePolicies and reports count' {
            $output = & $script:SeedScriptPath -Categories UpgradePolicies

            $output | Should -Not -BeNullOrEmpty
            ($output -match '=== Seeding Upgrade Policies ===') | Should -Not -BeNullOrEmpty
            ($output -match 'Upgrade policies seeded: 3') | Should -Not -BeNullOrEmpty
        }
    }

    Context '-Categories TDADPolicies dispatch' {
        BeforeAll {
            $fakeSession = New-TestSession -SkipCert
            $realModule = Get-Module PSSymantecSEPM

            Mock Import-Module { return $realModule }
            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }

            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                if ($Method -eq 'GET') {
                    return @{
                        content = @(
                            @{ name = 'TDAD Enabled'; id = 'id-t1' }
                            @{ name = 'TDAD Disabled'; id = 'id-t2' }
                        )
                    }
                }
                return $null
            }
        }

        It 'dispatches to Invoke-SeedTDADPolicies and reports count' {
            $output = & $script:SeedScriptPath -Categories TDADPolicies

            $output | Should -Not -BeNullOrEmpty
            ($output -match '=== Seeding TDAD Policies ===') | Should -Not -BeNullOrEmpty
            ($output -match 'TDAD policies seeded: 2') | Should -Not -BeNullOrEmpty
        }
    }
}
