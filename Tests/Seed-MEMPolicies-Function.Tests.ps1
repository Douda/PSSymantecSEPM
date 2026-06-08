[CmdletBinding()]
param()

Describe 'Invoke-SeedMEMPolicies' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment

        InModuleScope PSSymantecSEPM {
            $script:configurationFilePath = Join-Path -Path 'TestDrive:' -ChildPath 'config.json'
            $script:credentialsFilePath   = Join-Path -Path 'TestDrive:' -ChildPath 'creds.xml'
            $script:accessTokenFilePath   = Join-Path -Path 'TestDrive:' -ChildPath 'token.xml'
        }

        $script:SeedScriptPath = Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath 'Scripts/Seed-MEMPolicies.ps1'
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context 'Tracer bullet' {
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
                    $id = "id-$($bodyObj.name -replace ' ','-')"
                    $script:policyList.Add(@{ name = $bodyObj.name; id = $id })
                    return $null
                }
                if ($Method -eq 'PATCH') { return $null }
                return $null
            }

            . $script:SeedScriptPath
        }

        It 'returns a state hashtable with MEMPolicyMap' {
            $script:policyList.Clear()
            $State = @{ Force = $false; Session = (New-TestSession -SkipCert) }
            $output = Invoke-SeedMEMPolicies -State $State
            $output | Should -Not -BeNullOrEmpty
            $output -is [hashtable] | Should -BeTrue
            $output.ContainsKey('MEMPolicyMap') | Should -BeTrue
        }

        It 'maps all 4 policies by name' {
            $script:policyList.Clear()
            $State = @{ Force = $false; Session = $fakeSession }
            $output = Invoke-SeedMEMPolicies -State $State
            $output.MEMPolicyMap['Standard MEM'] | Should -Be 'id-Standard-MEM'
            $output.MEMPolicyMap['Advanced MEM'] | Should -Be 'id-Advanced-MEM'
            $output.MEMPolicyMap['Java-Only MEM'] | Should -Be 'id-Java-Only-MEM'
            $output.MEMPolicyMap['Audit MEM'] | Should -Be 'id-Audit-MEM'
        }
    }

    Context 'Creates all 4 policies' {
        BeforeAll {
            $fakeSession = New-TestSession -SkipCert

            $script:policyList = [System.Collections.Generic.List[object]]::new()
            $script:postBodies = @()
            $script:patchBodies = @()

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
                if ($Method -eq 'PATCH') {
                    $script:patchBodies += $Body
                    return $null
                }
                return $null
            }

            . $script:SeedScriptPath

            $State = @{ Force = $false; Session = $fakeSession }
            $script:result = Invoke-SeedMEMPolicies -State $State
        }

        It 'populates MEMPolicyMap with 4 entries' {
            $script:result.MEMPolicyMap.Count | Should -Be 4
        }

        It 'sends 4 POST requests' {
            $script:postBodies.Count | Should -Be 4
        }

        It 'sends no PATCH requests (POST sets full config)' {
            $script:patchBodies.Count | Should -Be 0
        }

        It 'POST body includes full configuration' {
            $firstPost = $script:postBodies[0] | ConvertFrom-Json
            $firstPost.name | Should -Be 'Standard MEM'
            $firstPost.desc | Should -Not -BeNullOrEmpty
            $firstPost.enabled | Should -BeTrue
            $firstPost.configuration | Should -Not -BeNullOrEmpty
            $firstPost.configuration.enabled | Should -BeTrue
            $firstPost.configuration.enablejavaprotection | Should -BeTrue
            $firstPost.configuration.enableadvanced | Should -BeFalse
        }

        It 'POST body for Advanced MEM has customrules and globaltechniqueoverrides' {
            $advancedPost = $script:postBodies[1] | ConvertFrom-Json
            $advancedPost.name | Should -Be 'Advanced MEM'
            $advancedPost.configuration.enableadvanced | Should -BeTrue
            $advancedPost.configuration.customrules.Count | Should -BeGreaterOrEqual 2
            $advancedPost.configuration.globaltechniqueoverrides.Count | Should -BeGreaterOrEqual 1
        }

        It 'Java-Only MEM POST body has config.enabled=false, enablejavaprotection=true' {
            $javaPost = $script:postBodies[2] | ConvertFrom-Json
            $javaPost.name | Should -Be 'Java-Only MEM'
            $javaPost.enabled | Should -BeTrue
            $javaPost.configuration.enabled | Should -BeFalse
            $javaPost.configuration.enablejavaprotection | Should -BeTrue
            $javaPost.configuration.enableadvanced | Should -BeFalse
        }

        It 'Audit MEM POST body has globalauditmodeoverride=true' {
            $auditPost = $script:postBodies[3] | ConvertFrom-Json
            $auditPost.name | Should -Be 'Audit MEM'
            $auditPost.configuration.globalauditmodeoverride | Should -BeTrue
        }
    }

    Context 'Idempotency' {
        BeforeAll {
            $fakeSession = New-TestSession -SkipCert

            $script:policyList = [System.Collections.Generic.List[object]]::new()
            $script:policyList.Add(@{ name = 'Standard MEM'; id = 'existing-1' })
            $script:policyList.Add(@{ name = 'Advanced MEM'; id = 'existing-2' })
            $script:policyList.Add(@{ name = 'Java-Only MEM'; id = 'existing-3' })
            $script:policyList.Add(@{ name = 'Audit MEM'; id = 'existing-4' })

            Mock Invoke-SepmApi {
                if ($Method -eq 'GET') {
                    return @{ content = $script:policyList.ToArray() }
                }
                throw "POST/DELETE should not be called for idempotent runs"
            }

            . $script:SeedScriptPath

            $State = @{ Force = $false; Session = $fakeSession }
            $script:result = Invoke-SeedMEMPolicies -State $State
        }

        It 'does not POST any new policies' {
            $script:result.MEMPolicyMap.Count | Should -Be 4
        }

        It 'maps existing IDs from GET response' {
            $script:result.MEMPolicyMap['Standard MEM'] | Should -Be 'existing-1'
            $script:result.MEMPolicyMap['Advanced MEM'] | Should -Be 'existing-2'
            $script:result.MEMPolicyMap['Java-Only MEM'] | Should -Be 'existing-3'
            $script:result.MEMPolicyMap['Audit MEM'] | Should -Be 'existing-4'
        }
    }

    Context 'Partial idempotency (some exist, some new)' {
        BeforeAll {
            $fakeSession = New-TestSession -SkipCert

            $script:policyList = [System.Collections.Generic.List[object]]::new()
            $script:policyList.Add(@{ name = 'Standard MEM'; id = 'existing-1' })
            $script:policyList.Add(@{ name = 'Advanced MEM'; id = 'existing-2' })

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
            $script:result = Invoke-SeedMEMPolicies -State $State
        }

        It 'skips existing, creates only 2 new ones' {
            $script:postBodies.Count | Should -Be 2
        }

        It 'uses existing IDs' {
            $script:result.MEMPolicyMap['Standard MEM'] | Should -Be 'existing-1'
            $script:result.MEMPolicyMap['Advanced MEM'] | Should -Be 'existing-2'
        }

        It 'assigns new IDs for new policies' {
            $script:result.MEMPolicyMap['Java-Only MEM'] | Should -Be 'new-Java-Only-MEM'
            $script:result.MEMPolicyMap['Audit MEM'] | Should -Be 'new-Audit-MEM'
        }
    }

    Context 'Force reset' {
        BeforeAll {
            $fakeSession = New-TestSession -SkipCert

            $script:policyList = [System.Collections.Generic.List[object]]::new()
            $script:policyList.Add(@{ name = 'Standard MEM'; id = 'old-1' })
            $script:policyList.Add(@{ name = 'Advanced MEM'; id = 'old-2' })
            $script:policyList.Add(@{ name = 'Java-Only MEM'; id = 'old-3' })
            $script:policyList.Add(@{ name = 'Audit MEM'; id = 'old-4' })

            $script:deleteCalls = @()
            $script:postBodies = @()

            Mock Invoke-SepmApi {
                if ($Method -eq 'GET') {
                    return @{ content = $script:policyList.ToArray() }
                }
                if ($Method -eq 'PATCH') {
                    # This handles the pre-delete disable PATCH (enabled=false)
                    # Distinguished from post-create config PATCH by checking the body
                    $bodyObj = $Body | ConvertFrom-Json
                    if ($bodyObj.PSObject.Properties.Name -contains 'enabled' -and $bodyObj.enabled -eq $false) {
                        return $null  # disable PATCH
                    }
                    return $null  # config PATCH
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
            $script:result = Invoke-SeedMEMPolicies -State $State
        }

        It 'deletes all 4 seed policies' {
            $script:deleteCalls.Count | Should -Be 4
        }

        It 'recreates all 4 after deletion' {
            $script:postBodies.Count | Should -Be 4
        }

        It 'maps recreated IDs' {
            $script:result.MEMPolicyMap['Standard MEM'] | Should -Be 'recreated-Standard-MEM'
            $script:result.MEMPolicyMap['Advanced MEM'] | Should -Be 'recreated-Advanced-MEM'
            $script:result.MEMPolicyMap['Java-Only MEM'] | Should -Be 'recreated-Java-Only-MEM'
            $script:result.MEMPolicyMap['Audit MEM'] | Should -Be 'recreated-Audit-MEM'
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
            $script:result = Invoke-SeedMEMPolicies -State $script:inputState
        }

        It 'preserves existing state keys' {
            $script:result.ExistingKey | Should -Be 'preserved-value'
        }

        It 'adds MEMPolicyMap alongside existing keys' {
            $script:result.ContainsKey('MEMPolicyMap') | Should -BeTrue
            $script:result.ContainsKey('ExistingKey') | Should -BeTrue
        }
    }
}
