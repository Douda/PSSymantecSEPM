[CmdletBinding()]
param()

Describe 'Invoke-SeedExceptionsPolicies' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment

        InModuleScope PSSymantecSEPM {
            $script:configurationFilePath = Join-Path -Path 'TestDrive:' -ChildPath 'config.json'
            $script:credentialsFilePath   = Join-Path -Path 'TestDrive:' -ChildPath 'creds.xml'
            $script:accessTokenFilePath   = Join-Path -Path 'TestDrive:' -ChildPath 'token.xml'
        }

        $script:SeedScriptPath = Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath 'Scripts/Seed-ExceptionsPolicies.ps1'
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context 'Tracer bullet' {
        BeforeAll {
            $fakeSession = New-TestSession -SkipCert

            # Accumulating policy list: the mock adds to this on POST and returns it on GET
            $script:policyList = [System.Collections.Generic.List[object]]::new()

            $script:postBodies = @()
            Mock Invoke-SepmApi {
                if ($Method -eq 'GET') {
                    return @{ content = $script:policyList.ToArray() }
                }
                if ($Method -eq 'POST') {
                    $script:postBodies += $Body
                    # Simulate creation: add to policy list for next GET
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

        It 'returns a state hashtable with ExceptionPolicyMap' {
            $script:policyList.Clear()
            $State = @{ Force = $false; Session = (New-TestSession -SkipCert) }
            $output = Invoke-SeedExceptionsPolicies -State $State
            $output | Should -Not -BeNullOrEmpty
            $output -is [hashtable] | Should -BeTrue
            $output.ContainsKey('ExceptionPolicyMap') | Should -BeTrue
        }

        It 'maps all 4 policies by name' {
            $script:policyList.Clear()
            $State = @{ Force = $false; Session = $fakeSession }
            $output = Invoke-SeedExceptionsPolicies -State $State
            $output.ExceptionPolicyMap['Standard Workstation Exceptions'] | Should -Be 'id-Standard-Workstation-Exceptions'
            $output.ExceptionPolicyMap['Server Exceptions'] | Should -Be 'id-Server-Exceptions'
            $output.ExceptionPolicyMap['Developer Exceptions'] | Should -Be 'id-Developer-Exceptions'
            $output.ExceptionPolicyMap['Emergency Disabled'] | Should -Be 'id-Emergency-Disabled'
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
            $script:result = Invoke-SeedExceptionsPolicies -State $State
        }

        It 'populates ExceptionPolicyMap with 4 entries' {
            $script:result.ExceptionPolicyMap.Count | Should -Be 4
        }

        It 'sends 4 POST requests' {
            $script:postBodies.Count | Should -Be 4
        }

        It 'sends 4 PATCH requests' {
            $script:patchBodies.Count | Should -Be 4
        }

        It 'POST body is minimal (name, desc, enabled)' {
            $firstPost = $script:postBodies[0] | ConvertFrom-Json
            $firstPost.name | Should -Be 'Standard Workstation Exceptions'
            $firstPost.desc | Should -Not -BeNullOrEmpty
            $firstPost.enabled | Should -BeTrue
            $firstPost.PSObject.Properties.Name | Should -Not -Contain 'configuration'
        }

        It 'PATCH body includes full configuration' {
            $standardPatch = $script:patchBodies[0] | ConvertFrom-Json
            $standardPatch.name | Should -Be 'Standard Workstation Exceptions'
            $standardPatch.configuration | Should -Not -BeNullOrEmpty
            $standardPatch.configuration.files.Count | Should -BeGreaterOrEqual 3
            $standardPatch.configuration.directories.Count | Should -BeGreaterOrEqual 2
        }

        It 'PATCH body for Server policy has tamper_files but no files/directories' {
            $serverPatch = $script:patchBodies[1] | ConvertFrom-Json
            $serverPatch.name | Should -Be 'Server Exceptions'
            $serverPatch.configuration.tamper_files.Count | Should -BeGreaterOrEqual 1
            $props = $serverPatch.configuration.PSObject.Properties.Name
            $props -contains 'files' | Should -BeFalse
            $props -contains 'directories' | Should -BeFalse
            $props -contains 'extension_list' | Should -BeFalse
        }

        It 'Emergency Disabled POST body has enabled=false' {
            $emergencyPost = $script:postBodies[3] | ConvertFrom-Json
            $emergencyPost.name | Should -Be 'Emergency Disabled'
            $emergencyPost.enabled | Should -BeFalse
        }

        It 'each enriched PATCH entry has rulestate and deleted' {
            $standardPatch = $script:patchBodies[0] | ConvertFrom-Json
            $firstFile = $standardPatch.configuration.files[0]
            $firstFile.rulestate | Should -Not -BeNullOrEmpty
            $firstFile.rulestate.enabled | Should -BeTrue
            $firstFile.rulestate.source | Should -Be 'PSSymantecSEPM'
            $firstFile.deleted | Should -BeFalse
        }
    }

    Context 'Idempotency' {
        BeforeAll {
            $fakeSession = New-TestSession -SkipCert

            $script:policyList = [System.Collections.Generic.List[object]]::new()
            $script:policyList.Add(@{ name = 'Standard Workstation Exceptions'; id = 'existing-1' })
            $script:policyList.Add(@{ name = 'Server Exceptions'; id = 'existing-2' })
            $script:policyList.Add(@{ name = 'Developer Exceptions'; id = 'existing-3' })
            $script:policyList.Add(@{ name = 'Emergency Disabled'; id = 'existing-4' })

            Mock Invoke-SepmApi {
                if ($Method -eq 'GET') {
                    return @{ content = $script:policyList.ToArray() }
                }
                throw "POST/PATCH/DELETE should not be called for idempotent runs"
            }

            . $script:SeedScriptPath

            $State = @{ Force = $false; Session = $fakeSession }
            $script:result = Invoke-SeedExceptionsPolicies -State $State
        }

        It 'does not POST any new policies' {
            $script:result.ExceptionPolicyMap.Count | Should -Be 4
        }

        It 'maps existing IDs from GET response' {
            $script:result.ExceptionPolicyMap['Standard Workstation Exceptions'] | Should -Be 'existing-1'
            $script:result.ExceptionPolicyMap['Server Exceptions'] | Should -Be 'existing-2'
            $script:result.ExceptionPolicyMap['Developer Exceptions'] | Should -Be 'existing-3'
            $script:result.ExceptionPolicyMap['Emergency Disabled'] | Should -Be 'existing-4'
        }
    }

    Context 'Partial idempotency (some exist, some new)' {
        BeforeAll {
            $fakeSession = New-TestSession -SkipCert

            $script:policyList = [System.Collections.Generic.List[object]]::new()
            $script:policyList.Add(@{ name = 'Standard Workstation Exceptions'; id = 'existing-1' })
            $script:policyList.Add(@{ name = 'Server Exceptions'; id = 'existing-2' })

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
            $script:result = Invoke-SeedExceptionsPolicies -State $State
        }

        It 'skips existing, creates only 2 new ones' {
            $script:postBodies.Count | Should -Be 2
        }

        It 'uses existing IDs' {
            $script:result.ExceptionPolicyMap['Standard Workstation Exceptions'] | Should -Be 'existing-1'
            $script:result.ExceptionPolicyMap['Server Exceptions'] | Should -Be 'existing-2'
        }

        It 'assigns new IDs for new policies' {
            $script:result.ExceptionPolicyMap['Developer Exceptions'] | Should -Be 'new-Developer-Exceptions'
            $script:result.ExceptionPolicyMap['Emergency Disabled'] | Should -Be 'new-Emergency-Disabled'
        }
    }

    Context 'Force reset' {
        BeforeAll {
            $fakeSession = New-TestSession -SkipCert

            $script:policyList = [System.Collections.Generic.List[object]]::new()
            $script:policyList.Add(@{ name = 'Standard Workstation Exceptions'; id = 'old-1' })
            $script:policyList.Add(@{ name = 'Server Exceptions'; id = 'old-2' })
            $script:policyList.Add(@{ name = 'Developer Exceptions'; id = 'old-3' })
            $script:policyList.Add(@{ name = 'Emergency Disabled'; id = 'old-4' })

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
                    # Remove from policy list (simulating deletion)
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
            $script:result = Invoke-SeedExceptionsPolicies -State $State
        }

        It 'deletes all 4 seed policies' {
            $script:deleteCalls.Count | Should -Be 4
        }

        It 'recreates all 4 after deletion' {
            $script:postBodies.Count | Should -Be 4
        }

        It 'maps recreated IDs' {
            $script:result.ExceptionPolicyMap['Standard Workstation Exceptions'] | Should -Be 'recreated-Standard-Workstation-Exceptions'
            $script:result.ExceptionPolicyMap['Server Exceptions'] | Should -Be 'recreated-Server-Exceptions'
            $script:result.ExceptionPolicyMap['Developer Exceptions'] | Should -Be 'recreated-Developer-Exceptions'
            $script:result.ExceptionPolicyMap['Emergency Disabled'] | Should -Be 'recreated-Emergency-Disabled'
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
            $script:result = Invoke-SeedExceptionsPolicies -State $script:inputState
        }

        It 'preserves existing state keys' {
            $script:result.ExistingKey | Should -Be 'preserved-value'
        }

        It 'adds ExceptionPolicyMap alongside existing keys' {
            $script:result.ContainsKey('ExceptionPolicyMap') | Should -BeTrue
            $script:result.ContainsKey('ExistingKey') | Should -BeTrue
        }
    }
}
