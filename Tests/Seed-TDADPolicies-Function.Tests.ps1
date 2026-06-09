[CmdletBinding()]
param()

Describe 'Invoke-SeedTDADPolicies' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment

        $script:SeedScriptPath = Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath 'Scripts/Seed-TDADPolicies.ps1'
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

        It 'returns a state hashtable with TDADPolicyMap' {
            $script:policyList.Clear()
            $State = @{ Force = $false; Session = (New-TestSession -SkipCert) }
            $output = Invoke-SeedTDADPolicies -State $State
            $output | Should -Not -BeNullOrEmpty
            $output -is [hashtable] | Should -BeTrue
            $output.ContainsKey('TDADPolicyMap') | Should -BeTrue
        }

        It 'maps both policies by name' {
            $script:policyList.Clear()
            $State = @{ Force = $false; Session = $fakeSession }
            $output = Invoke-SeedTDADPolicies -State $State
            $output.TDADPolicyMap['TDAD Enabled'] | Should -Be 'id-TDAD-Enabled'
            $output.TDADPolicyMap['TDAD Disabled'] | Should -Be 'id-TDAD-Disabled'
        }
    }

    Context 'Creates both policies' {
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
            $script:result = Invoke-SeedTDADPolicies -State $State
        }

        It 'populates TDADPolicyMap with 2 entries' {
            $script:result.TDADPolicyMap.Count | Should -Be 2
        }

        It 'sends 2 POST requests' {
            $script:postBodies.Count | Should -Be 2
        }

        It 'TDAD Enabled POST body has configuration.enabled=true and empty ad_domains' {
            $enabled = $script:postBodies[0] | ConvertFrom-Json
            $enabled.name | Should -Be 'TDAD Enabled'
            $enabled.desc | Should -Not -BeNullOrEmpty
            $enabled.enabled | Should -BeTrue
            $enabled.configuration.enabled | Should -BeTrue
            $enabled.configuration.ad_domains | Should -BeNullOrEmpty
        }

        It 'TDAD Disabled POST body has configuration.enabled=false' {
            $disabled = $script:postBodies[1] | ConvertFrom-Json
            $disabled.name | Should -Be 'TDAD Disabled'
            $disabled.enabled | Should -BeFalse
            $disabled.configuration.enabled | Should -BeFalse
            $disabled.configuration.ad_domains | Should -BeNullOrEmpty
        }
    }

    Context 'Idempotency' {
        BeforeAll {
            $fakeSession = New-TestSession -SkipCert

            $script:policyList = [System.Collections.Generic.List[object]]::new()
            $script:policyList.Add(@{ name = 'TDAD Enabled'; id = 'existing-1' })
            $script:policyList.Add(@{ name = 'TDAD Disabled'; id = 'existing-2' })

            Mock Invoke-SepmApi {
                if ($Method -eq 'GET') {
                    return @{ content = $script:policyList.ToArray() }
                }
                throw "POST/DELETE should not be called for idempotent runs"
            }

            . $script:SeedScriptPath

            $State = @{ Force = $false; Session = $fakeSession }
            $script:result = Invoke-SeedTDADPolicies -State $State
        }

        It 'does not POST any new policies' {
            $script:result.TDADPolicyMap.Count | Should -Be 2
        }

        It 'maps existing IDs from GET response' {
            $script:result.TDADPolicyMap['TDAD Enabled'] | Should -Be 'existing-1'
            $script:result.TDADPolicyMap['TDAD Disabled'] | Should -Be 'existing-2'
        }
    }

    Context 'Partial idempotency (some exist, some new)' {
        BeforeAll {
            $fakeSession = New-TestSession -SkipCert

            $script:policyList = [System.Collections.Generic.List[object]]::new()
            $script:policyList.Add(@{ name = 'TDAD Enabled'; id = 'existing-1' })

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
            $script:result = Invoke-SeedTDADPolicies -State $State
        }

        It 'skips existing, creates only 1 new' {
            $script:postBodies.Count | Should -Be 1
        }

        It 'uses existing ID for TDAD Enabled' {
            $script:result.TDADPolicyMap['TDAD Enabled'] | Should -Be 'existing-1'
        }

        It 'assigns new ID for new policy' {
            $script:result.TDADPolicyMap['TDAD Disabled'] | Should -Be 'new-TDAD-Disabled'
        }
    }

    Context 'Force reset' {
        BeforeAll {
            $fakeSession = New-TestSession -SkipCert

            $script:policyList = [System.Collections.Generic.List[object]]::new()
            $script:policyList.Add(@{ name = 'TDAD Enabled'; id = 'old-1' })
            $script:policyList.Add(@{ name = 'TDAD Disabled'; id = 'old-2' })

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
            $script:result = Invoke-SeedTDADPolicies -State $State
        }

        It 'deletes both seed policies' {
            $script:deleteCalls.Count | Should -Be 2
        }

        It 'recreates both after deletion' {
            $script:postBodies.Count | Should -Be 2
        }

        It 'maps recreated IDs' {
            $script:result.TDADPolicyMap['TDAD Enabled'] | Should -Be 'recreated-TDAD-Enabled'
            $script:result.TDADPolicyMap['TDAD Disabled'] | Should -Be 'recreated-TDAD-Disabled'
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
            $script:result = Invoke-SeedTDADPolicies -State $script:inputState
        }

        It 'preserves existing state keys' {
            $script:result.ExistingKey | Should -Be 'preserved-value'
        }

        It 'adds TDADPolicyMap alongside existing keys' {
            $script:result.ContainsKey('TDADPolicyMap') | Should -BeTrue
            $script:result.ContainsKey('ExistingKey') | Should -BeTrue
        }
    }
}
