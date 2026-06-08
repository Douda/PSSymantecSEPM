[CmdletBinding()]
param()

Describe 'Invoke-SeedUpgradePolicies' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment

        InModuleScope PSSymantecSEPM {
            $script:configurationFilePath = Join-Path -Path 'TestDrive:' -ChildPath 'config.json'
            $script:credentialsFilePath   = Join-Path -Path 'TestDrive:' -ChildPath 'creds.xml'
            $script:accessTokenFilePath   = Join-Path -Path 'TestDrive:' -ChildPath 'token.xml'
        }

        $script:SeedScriptPath = Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath 'Scripts/Seed-UpgradePolicies.ps1'
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context 'Tracer bullet' {
        BeforeAll {
            $fakeSession = New-TestSession -SkipCert

            $script:policyList = [System.Collections.Generic.List[object]]::new()

            Mock Invoke-SepmApi {
                if ($Method -eq 'GET') {
                    return @{ content = $script:policyList.ToArray() }
                }
                if ($Method -eq 'POST') {
                    $bodyObj = $Body | ConvertFrom-Json
                    $id = "id-$($bodyObj.name -replace ' ','-')"
                    $script:policyList.Add(@{ name = $bodyObj.name; id = $id })
                    return $null
                }
                if ($Method -eq 'PATCH') { return $null }
                return $null
            }

            . $script:SeedScriptPath
        }

        It 'returns a state hashtable with UpgradePolicyMap' {
            $script:policyList.Clear()
            $State = @{ Force = $false; Session = (New-TestSession -SkipCert) }
            $output = Invoke-SeedUpgradePolicies -State $State
            $output | Should -Not -BeNullOrEmpty
            $output -is [hashtable] | Should -BeTrue
            $output.ContainsKey('UpgradePolicyMap') | Should -BeTrue
        }

        It 'maps all 3 policies by name' {
            $script:policyList.Clear()
            $State = @{ Force = $false; Session = $fakeSession }
            $output = Invoke-SeedUpgradePolicies -State $State
            $output.UpgradePolicyMap['Zero-Day Upgrade'] | Should -Be 'id-Zero-Day-Upgrade'
            $output.UpgradePolicyMap['Weekend Upgrade'] | Should -Be 'id-Weekend-Upgrade'
            $output.UpgradePolicyMap['Manual Upgrade'] | Should -Be 'id-Manual-Upgrade'
        }
    }

    Context 'Creates all 3 policies' {
        BeforeAll {
            $fakeSession = New-TestSession -SkipCert

            $script:policyList = [System.Collections.Generic.List[object]]::new()
            $script:postBodies = @()

            Mock Invoke-SepmApi {
                if ($Method -eq 'GET') {
                    return @{ content = $script:policyList.ToArray() }
                }
                if ($Method -eq 'POST') {
                    $script:postBodies += $Body
                    $bodyObj = $Body | ConvertFrom-Json
                    $id = "seed-$($bodyObj.name -replace ' ','-')"
                    $script:policyList.Add(@{ name = $bodyObj.name; id = $id })
                    return $null
                }
                if ($Method -eq 'PATCH') { return $null }
                return $null
            }

            . $script:SeedScriptPath

            $State = @{ Force = $false; Session = $fakeSession }
            $script:result = Invoke-SeedUpgradePolicies -State $State
        }

        It 'populates UpgradePolicyMap with 3 entries' {
            $script:result.UpgradePolicyMap.Count | Should -Be 3
        }

        It 'sends 3 POST requests' {
            $script:postBodies.Count | Should -Be 3
        }

        It 'Zero-Day POST body has release_delay_days=0 and all days enabled' {
            $zd = $script:postBodies[0] | ConvertFrom-Json
            $zd.name | Should -Be 'Zero-Day Upgrade'
            $zd.desc | Should -Not -BeNullOrEmpty
            $zd.enabled | Should -BeTrue
            $zd.configuration.release_delay_days | Should -Be 0
            $zd.configuration.schedule.daily.monday    | Should -BeTrue
            $zd.configuration.schedule.daily.tuesday   | Should -BeTrue
            $zd.configuration.schedule.daily.wednesday | Should -BeTrue
            $zd.configuration.schedule.daily.thursday  | Should -BeTrue
            $zd.configuration.schedule.daily.friday    | Should -BeTrue
            $zd.configuration.schedule.daily.saturday  | Should -BeTrue
            $zd.configuration.schedule.daily.sunday    | Should -BeTrue
            $zd.configuration.schedule.time_window | Should -Be 86400
            $zd.configuration.schedule.retry_enabled | Should -BeTrue
        }

        It 'Weekend POST body has release_delay_days=7 and only Saturday+Sunday enabled' {
            $we = $script:postBodies[1] | ConvertFrom-Json
            $we.name | Should -Be 'Weekend Upgrade'
            $we.enabled | Should -BeTrue
            $we.configuration.release_delay_days | Should -Be 7
            $we.configuration.schedule.daily.monday    | Should -BeFalse
            $we.configuration.schedule.daily.tuesday   | Should -BeFalse
            $we.configuration.schedule.daily.wednesday | Should -BeFalse
            $we.configuration.schedule.daily.thursday  | Should -BeFalse
            $we.configuration.schedule.daily.friday    | Should -BeFalse
            $we.configuration.schedule.daily.saturday  | Should -BeTrue
            $we.configuration.schedule.daily.sunday    | Should -BeTrue
            $we.configuration.schedule.time_window | Should -Be 14400
            $we.configuration.schedule.retry_enabled | Should -BeTrue
        }

        It 'Manual Upgrade POST body has enabled=false' {
            $mu = $script:postBodies[2] | ConvertFrom-Json
            $mu.name | Should -Be 'Manual Upgrade'
            $mu.enabled | Should -BeFalse
        }
    }

    Context 'Idempotency' {
        BeforeAll {
            $fakeSession = New-TestSession -SkipCert

            $script:policyList = [System.Collections.Generic.List[object]]::new()
            $script:policyList.Add(@{ name = 'Zero-Day Upgrade'; id = 'existing-zd' })
            $script:policyList.Add(@{ name = 'Weekend Upgrade'; id = 'existing-we' })
            $script:policyList.Add(@{ name = 'Manual Upgrade'; id = 'existing-mu' })

            Mock Invoke-SepmApi {
                if ($Method -eq 'GET') {
                    return @{ content = $script:policyList.ToArray() }
                }
                throw "POST/DELETE should not be called for idempotent runs"
            }

            . $script:SeedScriptPath

            $State = @{ Force = $false; Session = $fakeSession }
            $script:result = Invoke-SeedUpgradePolicies -State $State
        }

        It 'does not POST any new policies' {
            $script:result.UpgradePolicyMap.Count | Should -Be 3
        }

        It 'maps existing IDs from GET response' {
            $script:result.UpgradePolicyMap['Zero-Day Upgrade'] | Should -Be 'existing-zd'
            $script:result.UpgradePolicyMap['Weekend Upgrade'] | Should -Be 'existing-we'
            $script:result.UpgradePolicyMap['Manual Upgrade'] | Should -Be 'existing-mu'
        }
    }

    Context 'Partial idempotency (some exist, some new)' {
        BeforeAll {
            $fakeSession = New-TestSession -SkipCert

            $script:policyList = [System.Collections.Generic.List[object]]::new()
            $script:policyList.Add(@{ name = 'Zero-Day Upgrade'; id = 'existing-zd' })

            $script:postBodies = @()

            Mock Invoke-SepmApi {
                if ($Method -eq 'GET') {
                    return @{ content = $script:policyList.ToArray() }
                }
                if ($Method -eq 'POST') {
                    $script:postBodies += $Body
                    $bodyObj = $Body | ConvertFrom-Json
                    $id = "new-$($bodyObj.name -replace ' ','-')"
                    $script:policyList.Add(@{ name = $bodyObj.name; id = $id })
                    return $null
                }
                if ($Method -eq 'PATCH') { return $null }
                return $null
            }

            . $script:SeedScriptPath

            $State = @{ Force = $false; Session = $fakeSession }
            $script:result = Invoke-SeedUpgradePolicies -State $State
        }

        It 'skips existing, creates only 2 new ones' {
            $script:postBodies.Count | Should -Be 2
        }

        It 'uses existing ID for Zero-Day' {
            $script:result.UpgradePolicyMap['Zero-Day Upgrade'] | Should -Be 'existing-zd'
        }

        It 'assigns new IDs for new policies' {
            $script:result.UpgradePolicyMap['Weekend Upgrade'] | Should -Be 'new-Weekend-Upgrade'
            $script:result.UpgradePolicyMap['Manual Upgrade'] | Should -Be 'new-Manual-Upgrade'
        }
    }

    Context 'Force reset' {
        BeforeAll {
            $fakeSession = New-TestSession -SkipCert

            $script:policyList = [System.Collections.Generic.List[object]]::new()
            $script:policyList.Add(@{ name = 'Zero-Day Upgrade'; id = 'old-zd' })
            $script:policyList.Add(@{ name = 'Weekend Upgrade'; id = 'old-we' })
            $script:policyList.Add(@{ name = 'Manual Upgrade'; id = 'old-mu' })

            $script:deleteCalls = @()
            $script:postBodies = @()

            Mock Invoke-SepmApi {
                if ($Method -eq 'GET') {
                    return @{ content = $script:policyList.ToArray() }
                }
                if ($Method -eq 'PATCH') {
                    $bodyObj = $Body | ConvertFrom-Json
                    if ($bodyObj.PSObject.Properties.Name -contains 'enabled' -and $bodyObj.enabled -eq $false) {
                        return $null
                    }
                    return $null
                }
                if ($Method -eq 'DELETE') {
                    $script:deleteCalls += $Uri
                    $idFromUri = ($Uri -split '/')[-1]
                    $toRemove = $script:policyList | Where-Object { $_.id -eq $idFromUri }
                    if ($toRemove) { $script:policyList.Remove($toRemove) }
                    return $null
                }
                if ($Method -eq 'POST') {
                    $script:postBodies += $Body
                    $bodyObj = $Body | ConvertFrom-Json
                    $id = "recreated-$($bodyObj.name -replace ' ','-')"
                    $script:policyList.Add(@{ name = $bodyObj.name; id = $id })
                    return $null
                }
                return $null
            }

            . $script:SeedScriptPath

            $State = @{ Force = $true; Session = $fakeSession }
            $script:result = Invoke-SeedUpgradePolicies -State $State
        }

        It 'deletes all 3 seed policies' {
            $script:deleteCalls.Count | Should -Be 3
        }

        It 'recreates all 3 after deletion' {
            $script:postBodies.Count | Should -Be 3
        }

        It 'maps recreated IDs' {
            $script:result.UpgradePolicyMap['Zero-Day Upgrade'] | Should -Be 'recreated-Zero-Day-Upgrade'
            $script:result.UpgradePolicyMap['Weekend Upgrade'] | Should -Be 'recreated-Weekend-Upgrade'
            $script:result.UpgradePolicyMap['Manual Upgrade'] | Should -Be 'recreated-Manual-Upgrade'
        }
    }

    Context 'State preservation' {
        BeforeAll {
            $fakeSession = New-TestSession -SkipCert

            $script:policyList = [System.Collections.Generic.List[object]]::new()

            Mock Invoke-SepmApi {
                if ($Method -eq 'GET') {
                    return @{ content = $script:policyList.ToArray() }
                }
                if ($Method -eq 'POST') {
                    $bodyObj = $Body | ConvertFrom-Json
                    $id = "id-$($bodyObj.name -replace ' ','-')"
                    $script:policyList.Add(@{ name = $bodyObj.name; id = $id })
                    return $null
                }
                if ($Method -eq 'PATCH') { return $null }
                return $null
            }

            . $script:SeedScriptPath

            $script:inputState = @{
                Force       = $false
                Session     = $fakeSession
                ExistingKey = 'preserved-value'
            }
            $script:result = Invoke-SeedUpgradePolicies -State $script:inputState
        }

        It 'preserves existing state keys' {
            $script:result.ExistingKey | Should -Be 'preserved-value'
        }

        It 'adds UpgradePolicyMap alongside existing keys' {
            $script:result.ContainsKey('UpgradePolicyMap') | Should -BeTrue
            $script:result.ContainsKey('ExistingKey') | Should -BeTrue
        }
    }
}
