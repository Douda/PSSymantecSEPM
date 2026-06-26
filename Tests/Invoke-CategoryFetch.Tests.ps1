[CmdletBinding()]
param()

Describe 'Invoke-CategoryFetch' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context 'Simple mode — success' {
        It 'executes the fetch script and stores result in the snapshot property' {
            InModuleScope PSSymantecSEPM {
                $snapshot = [PSCustomObject]@{ Domains = $null; Failures = @() }
                $progressCounter = 0

                Invoke-CategoryFetch -Category 'Domains' -Snapshot $snapshot -FetchScript { return @{ id = 'abc'; name = 'Default' } } -ProgressCounter ([ref]$progressCounter) -TotalSteps 25

                $snapshot.Domains | Should -Not -BeNullOrEmpty
                $snapshot.Domains.id | Should -Be 'abc'
                $snapshot.Domains.name | Should -Be 'Default'
            }
        }
    }

    Context 'Simple mode — failure' {
        It 'captures failure with uniform shape Category/Item/ItemId/Error' {
            InModuleScope PSSymantecSEPM {
                $snapshot = [PSCustomObject]@{ Version = $null; Failures = @() }
                $progressCounter = 0

                Invoke-CategoryFetch -Category 'Version' -Snapshot $snapshot -FetchScript { throw 'API timeout' } -ProgressCounter ([ref]$progressCounter) -TotalSteps 25

                $snapshot.Version | Should -Be $null
                $snapshot.Failures.Count | Should -Be 1
                $snapshot.Failures[0].Category | Should -Be 'Version'
                $snapshot.Failures[0].Item | Should -Be ''
                $snapshot.Failures[0].ItemId | Should -Be ''
                $snapshot.Failures[0].Error | Should -Be 'API timeout'
            }
        }

        It 'does not propagate the exception to the caller' {
            InModuleScope PSSymantecSEPM {
                $snapshot = [PSCustomObject]@{ Version = $null; Failures = @() }
                $progressCounter = 0

                { Invoke-CategoryFetch -Category 'Version' -Snapshot $snapshot -FetchScript { throw 'boom' } -ProgressCounter ([ref]$progressCounter) -TotalSteps 25 } | Should -Not -Throw
            }
        }
    }

    Context 'Iterative mode — empty items' {
        It 'does not error with empty items array' {
            InModuleScope PSSymantecSEPM {
                $snapshot = [PSCustomObject]@{ IpsPolicies = $null; Failures = @() }
                $progressCounter = 0

                { Invoke-CategoryFetch -Category 'IpsPolicies' -Snapshot $snapshot -Items @() -ItemFetchScript { return 'data' } -ProgressCounter ([ref]$progressCounter) -TotalSteps 25 } | Should -Not -Throw
            }
        }

        It 'stores empty array in snapshot for empty items' {
            InModuleScope PSSymantecSEPM {
                $snapshot = [PSCustomObject]@{ IpsPolicies = $null; Failures = @() }
                $progressCounter = 0

                Invoke-CategoryFetch -Category 'IpsPolicies' -Snapshot $snapshot -Items @() -ItemFetchScript { return 'data' } -ProgressCounter ([ref]$progressCounter) -TotalSteps 25

                $snapshot.IpsPolicies -is [array] | Should -Be $true
                $snapshot.IpsPolicies.Count | Should -Be 0
                $snapshot.Failures.Count | Should -Be 0
            }
        }
    }

    Context 'Iterative mode — single item' {
        It 'fetches and stores result for a single item' {
            InModuleScope PSSymantecSEPM {
                $snapshot = [PSCustomObject]@{ IpsPolicies = $null; Failures = @() }
                $progressCounter = 0
                $items = @([PSCustomObject]@{ id = 'POL001'; name = 'My IPS Policy' })

                Invoke-CategoryFetch -Category 'IpsPolicies' -Snapshot $snapshot -Items $items -ItemFetchScript { return [PSCustomObject]@{ id = $_.id; name = $_.name; rules = @() } } -ProgressCounter ([ref]$progressCounter) -TotalSteps 25

                $snapshot.IpsPolicies | Should -Not -BeNullOrEmpty
                $snapshot.IpsPolicies.Count | Should -Be 1
                $snapshot.IpsPolicies[0].id | Should -Be 'POL001'
                $snapshot.IpsPolicies[0].name | Should -Be 'My IPS Policy'
            }
        }
    }

    Context 'Iterative mode — per-item failure' {
        It 'captures per-item failure with uniform shape' {
            InModuleScope PSSymantecSEPM {
                $snapshot = [PSCustomObject]@{ IpsPolicies = $null; Failures = @() }
                $progressCounter = 0
                $items = @(
                    [PSCustomObject]@{ id = 'POL001'; name = 'Good Policy' },
                    [PSCustomObject]@{ id = 'POL002'; name = 'Bad Policy' },
                    [PSCustomObject]@{ id = 'POL003'; name = 'Another Good' }
                )

                Invoke-CategoryFetch -Category 'IpsPolicies' -Snapshot $snapshot -Items $items -ItemFetchScript {
                    if ($_.id -eq 'POL002') { throw 'API error for policy' }
                    return [PSCustomObject]@{ id = $_.id; name = $_.name }
                } -ProgressCounter ([ref]$progressCounter) -TotalSteps 25

                # Good items still collected
                $snapshot.IpsPolicies.Count | Should -Be 2
                $snapshot.IpsPolicies[0].id | Should -Be 'POL001'
                $snapshot.IpsPolicies[1].id | Should -Be 'POL003'

                # Failure captured with uniform shape
                $snapshot.Failures.Count | Should -Be 1
                $snapshot.Failures[0].Category | Should -Be 'IpsPolicies'
                $snapshot.Failures[0].Item | Should -Be 'Bad Policy'
                $snapshot.Failures[0].ItemId | Should -Be 'POL002'
                $snapshot.Failures[0].Error | Should -Be 'API error for policy'
            }
        }
    }

    Context 'Iterative mode — heartbeat' {
        It 'processes all items correctly with heartbeat 50 items' {
            InModuleScope PSSymantecSEPM {
                $snapshot = [PSCustomObject]@{ IpsPolicies = $null; Failures = @() }
                $progressCounter = 0
                $items = 1..50 | ForEach-Object {
                    [PSCustomObject]@{ id = "POL$([string]$_)"; name = "Policy $_" }
                }

                Invoke-CategoryFetch -Category 'IpsPolicies' -Snapshot $snapshot -Items $items -ItemFetchScript { return [PSCustomObject]@{ id = $_.id; name = $_.name } } -ProgressCounter ([ref]$progressCounter) -TotalSteps 25

                $snapshot.IpsPolicies.Count | Should -Be 50
                $snapshot.Failures.Count | Should -Be 0
            }
        }
    }

    Context 'Iterative mode — delay between items' {
        It 'inserts delay between items but not after last item' {
            InModuleScope PSSymantecSEPM {
                $snapshot = [PSCustomObject]@{ IpsPolicies = $null; Failures = @() }
                $progressCounter = 0
                $items = @(
                    [PSCustomObject]@{ id = 'POL001'; name = 'Policy 1' },
                    [PSCustomObject]@{ id = 'POL002'; name = 'Policy 2' },
                    [PSCustomObject]@{ id = 'POL003'; name = 'Policy 3' }
                )

                $delayMs = 50
                $sw = [System.Diagnostics.Stopwatch]::StartNew()
                Invoke-CategoryFetch -Category 'IpsPolicies' -Snapshot $snapshot -Items $items -ItemFetchScript { return 'data' } -ProgressCounter ([ref]$progressCounter) -TotalSteps 25 -DelayMs $delayMs
                $sw.Stop()

                # 3 items, 2 delays of 50ms each = at least 100ms
                $sw.ElapsedMilliseconds | Should -BeGreaterOrEqual 90
                $snapshot.IpsPolicies.Count | Should -Be 3
            }
        }

        It 'sleeps for 0ms when DelayMs is 0 (default)' {
            InModuleScope PSSymantecSEPM {
                $snapshot = [PSCustomObject]@{ IpsPolicies = $null; Failures = @() }
                $progressCounter = 0
                $items = @(
                    [PSCustomObject]@{ id = 'POL001'; name = 'Policy 1' },
                    [PSCustomObject]@{ id = 'POL002'; name = 'Policy 2' }
                )

                $sw = [System.Diagnostics.Stopwatch]::StartNew()
                Invoke-CategoryFetch -Category 'IpsPolicies' -Snapshot $snapshot -Items $items -ItemFetchScript { return 'data' } -ProgressCounter ([ref]$progressCounter) -TotalSteps 25
                $sw.Stop()

                # Default DelayMs=0, no delays expected
                $sw.ElapsedMilliseconds | Should -BeLessThan 50
                $snapshot.IpsPolicies.Count | Should -Be 2
            }
        }
    }

    Context 'Custom scriptblocks' {
        It 'uses custom ItemNameScript and ItemIdScript' {
            InModuleScope PSSymantecSEPM {
                $snapshot = [PSCustomObject]@{ CustomItems = $null; Failures = @() }
                $progressCounter = 0
                $items = @(
                    [PSCustomObject]@{ customId = 'C001'; displayName = 'Item One' },
                    [PSCustomObject]@{ customId = 'C002'; displayName = 'Item Two' }
                )

                Invoke-CategoryFetch -Category 'CustomItems' -Snapshot $snapshot -Items $items -ItemFetchScript { return [PSCustomObject]@{ id = $_.customId; name = $_.displayName } } -ItemNameScript { $_.displayName } -ItemIdScript { $_.customId } -ProgressCounter ([ref]$progressCounter) -TotalSteps 25

                $snapshot.CustomItems.Count | Should -Be 2
                $snapshot.CustomItems[0].id | Should -Be 'C001'
                $snapshot.CustomItems[1].id | Should -Be 'C002'
            }
        }
    }

    Context 'Progress counter' {
        It 'bumps progress counter exactly once per invocation' {
            InModuleScope PSSymantecSEPM {
                $snapshot = [PSCustomObject]@{ Domains = $null; Failures = @() }
                $progressCounter = 5

                Invoke-CategoryFetch -Category 'Domains' -Snapshot $snapshot -FetchScript { return 'data' } -ProgressCounter ([ref]$progressCounter) -TotalSteps 25

                $progressCounter | Should -Be 6
            }
        }

        It 'bumps progress counter in iterative mode too' {
            InModuleScope PSSymantecSEPM {
                $snapshot = [PSCustomObject]@{ IpsPolicies = $null; Failures = @() }
                $progressCounter = 10
                $items = @([PSCustomObject]@{ id = 'POL001'; name = 'Policy' })

                Invoke-CategoryFetch -Category 'IpsPolicies' -Snapshot $snapshot -Items $items -ItemFetchScript { return 'data' } -ProgressCounter ([ref]$progressCounter) -TotalSteps 25

                $progressCounter | Should -Be 11
            }
        }
    }
}
