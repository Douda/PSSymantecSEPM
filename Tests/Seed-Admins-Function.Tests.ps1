[CmdletBinding()]
param()

Describe 'Invoke-SeedAdmins' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment

        $script:SeedScriptPath = Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath 'Scripts/Seed-Admins.ps1'
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context 'Tracer bullet' {
        BeforeAll {
            $fakeSession = New-TestSession -SkipCert

            Mock Invoke-SepmApi {
                if ($Method -eq 'GET') { return @() }
                return @{ id = 'new-admin-id'; loginName = 'test-user' }
            }

            . $script:SeedScriptPath
        }

        It 'returns a state hashtable with AdminMap' {
            $State = @{ Force = $false; Session = (New-TestSession -SkipCert) }
            $output = Invoke-SeedAdmins -State $State
            $output | Should -Not -BeNullOrEmpty
            $output -is [hashtable] | Should -BeTrue
            $output.ContainsKey('AdminMap') | Should -BeTrue
        }
    }

    Context 'Creates all 6 admins' {
        BeforeAll {
            $fakeSession = New-TestSession -SkipCert

            # GET returns empty (no existing admins besides default)
            Mock Invoke-SepmApi {
                if ($Method -eq 'GET') { return @() }
                # POST: return the created admin with ID
                $bodyObj = $Body | ConvertFrom-Json
                return @{
                    id       = "id-$($bodyObj.loginName)"
                    loginName = $bodyObj.loginName
                    fullName  = $bodyObj.fullName
                    adminType = $bodyObj.adminType
                }
            }

            . $script:SeedScriptPath

            $State = @{ Force = $false; Session = $fakeSession }
            $script:result = Invoke-SeedAdmins -State $State
        }

        It 'populates AdminMap with 6 entries' {
            $script:result.AdminMap.Count | Should -Be 6
        }

        It 'maps loginNames to server IDs' {
            $script:result.AdminMap['jdoe'] | Should -Be 'id-jdoe'
            $script:result.AdminMap['soc-automation'] | Should -Be 'id-soc-automation'
            $script:result.AdminMap['helpdesk-lead'] | Should -Be 'id-helpdesk-lead'
            $script:result.AdminMap['emea-admin'] | Should -Be 'id-emea-admin'
            $script:result.AdminMap['ops-readonly'] | Should -Be 'id-ops-readonly'
            $script:result.AdminMap['sec-auditor'] | Should -Be 'id-sec-auditor'
        }
    }

    Context 'POST body includes correct fields' {
        BeforeAll {
            $fakeSession = New-TestSession -SkipCert

            Mock Invoke-SepmApi {
                if ($Method -eq 'GET') { return @() }
                $script:lastPostBody = $Body
                $bodyObj = $Body | ConvertFrom-Json
                return @{
                    id       = "id-$($bodyObj.loginName)"
                    loginName = $bodyObj.loginName
                }
            }

            . $script:SeedScriptPath

            $State = @{ Force = $false; Session = $fakeSession }
            $null = Invoke-SeedAdmins -State $State
        }

        It 'sends loginName in POST body' {
            # Capture from last POST (sec-auditor)
            $body = $script:lastPostBody | ConvertFrom-Json
            $body.loginName | Should -Not -BeNullOrEmpty
        }

        It 'sends fullName in POST body' {
            $body = $script:lastPostBody | ConvertFrom-Json
            $body.fullName | Should -Not -BeNullOrEmpty
        }

        It 'sends adminType in POST body' {
            $body = $script:lastPostBody | ConvertFrom-Json
            $body.adminType -is [int] -or $body.adminType -is [long] | Should -BeTrue
        }

        It 'sends emailAddress in POST body' {
            $body = $script:lastPostBody | ConvertFrom-Json
            $body.emailAddress | Should -Not -BeNullOrEmpty
        }

        It 'sends password in POST body' {
            $body = $script:lastPostBody | ConvertFrom-Json
            $body.password | Should -Be 'SeedPass123!'
        }

        It 'sends authenticationMethod=0 (SEPM auth)' {
            $body = $script:lastPostBody | ConvertFrom-Json
            $body.authenticationMethod | Should -Be 0
        }

        It 'sends enabled=true' {
            $body = $script:lastPostBody | ConvertFrom-Json
            $body.enabled | Should -BeTrue
        }

        It 'sends lockTimeThreshold in POST body' {
            $body = $script:lastPostBody | ConvertFrom-Json
            $body.lockTimeThreshold | Should -Be 15
        }

        It 'sends loginAttemptThreshold in POST body' {
            $body = $script:lastPostBody | ConvertFrom-Json
            $body.loginAttemptThreshold | Should -Be 3
        }

        It 'sends lockAccount=false in POST body' {
            $body = $script:lastPostBody | ConvertFrom-Json
            $body.lockAccount | Should -BeFalse
        }
    }

    Context 'Idempotency' {
        BeforeAll {
            # All 6 seed admins already exist
            Mock Invoke-SepmApi {
                if ($Method -eq 'GET') {
                    return @(
                        @{ id = 'existing-jdoe'; loginName = 'jdoe' },
                        @{ id = 'existing-soc'; loginName = 'soc-automation' },
                        @{ id = 'existing-helpdesk'; loginName = 'helpdesk-lead' },
                        @{ id = 'existing-emea'; loginName = 'emea-admin' },
                        @{ id = 'existing-ops'; loginName = 'ops-readonly' },
                        @{ id = 'existing-audit'; loginName = 'sec-auditor' }
                    )
                }
                # POST should never be called
                throw "POST should not be called for idempotent runs"
            }

            . $script:SeedScriptPath

            $State = @{ Force = $false; Session = (New-TestSession -SkipCert) }
            $script:result = Invoke-SeedAdmins -State $State
        }

        It 'does not POST any new admins' {
            $script:result.AdminMap.Count | Should -Be 6
        }

        It 'maps existing IDs from GET response' {
            $script:result.AdminMap['jdoe'] | Should -Be 'existing-jdoe'
            $script:result.AdminMap['soc-automation'] | Should -Be 'existing-soc'
            $script:result.AdminMap['helpdesk-lead'] | Should -Be 'existing-helpdesk'
            $script:result.AdminMap['emea-admin'] | Should -Be 'existing-emea'
            $script:result.AdminMap['ops-readonly'] | Should -Be 'existing-ops'
            $script:result.AdminMap['sec-auditor'] | Should -Be 'existing-audit'
        }
    }

    Context 'Partial idempotency (some exist, some new)' {
        BeforeAll {
            $script:postCalls = @()
            Mock Invoke-SepmApi {
                if ($Method -eq 'GET') {
                    return @(
                        @{ id = 'existing-jdoe'; loginName = 'jdoe' },
                        @{ id = 'existing-soc'; loginName = 'soc-automation' }
                    )
                }
                $script:postCalls += $Body | ConvertFrom-Json
                $bodyObj = $Body | ConvertFrom-Json
                return @{ id = "new-$($bodyObj.loginName)"; loginName = $bodyObj.loginName }
            }

            . $script:SeedScriptPath

            $State = @{ Force = $false; Session = (New-TestSession -SkipCert) }
            $script:result = Invoke-SeedAdmins -State $State
        }

        It 'skips existing admins, creates only new ones' {
            $script:postCalls.Count | Should -Be 4
        }

        It 'uses existing IDs for existing admins' {
            $script:result.AdminMap['jdoe'] | Should -Be 'existing-jdoe'
            $script:result.AdminMap['soc-automation'] | Should -Be 'existing-soc'
        }

        It 'assigns new IDs for new admins' {
            $script:result.AdminMap['helpdesk-lead'] | Should -Be 'new-helpdesk-lead'
            $script:result.AdminMap['emea-admin'] | Should -Be 'new-emea-admin'
            $script:result.AdminMap['ops-readonly'] | Should -Be 'new-ops-readonly'
            $script:result.AdminMap['sec-auditor'] | Should -Be 'new-sec-auditor'
        }
    }

    Context 'Force mode warns about no-delete and proceeds' {
        BeforeAll {
            # GET returns empty (no existing admins)
            Mock Invoke-SepmApi {
                if ($Method -eq 'GET') { return @() }
                $bodyObj = $Body | ConvertFrom-Json
                return @{ id = "id-$($bodyObj.loginName)"; loginName = $bodyObj.loginName }
            }

            . $script:SeedScriptPath

            $State = @{ Force = $true; Session = (New-TestSession -SkipCert) }
            $script:result = Invoke-SeedAdmins -State $State
        }

        It 'still creates all 6 admins with Force' {
            $script:result.AdminMap.Count | Should -Be 6
        }

        It 'maps all loginNames with Force' {
            $script:result.AdminMap['jdoe'] | Should -Be 'id-jdoe'
            $script:result.AdminMap['sec-auditor'] | Should -Be 'id-sec-auditor'
        }
    }

    Context 'State preservation' {
        BeforeAll {
            Mock Invoke-SepmApi {
                if ($Method -eq 'GET') { return @() }
                $bodyObj = $Body | ConvertFrom-Json
                return @{ id = "id-$($bodyObj.loginName)"; loginName = $bodyObj.loginName }
            }

            . $script:SeedScriptPath

            $script:inputState = @{
                Force    = $false
                Session  = (New-TestSession -SkipCert)
                ExistingKey = 'preserved-value'
            }
            $script:result = Invoke-SeedAdmins -State $script:inputState
        }

        It 'preserves existing state keys' {
            $script:result.ExistingKey | Should -Be 'preserved-value'
        }

        It 'adds AdminMap alongside existing keys' {
            $script:result.ContainsKey('AdminMap') | Should -BeTrue
            $script:result.ContainsKey('ExistingKey') | Should -BeTrue
        }
    }
}
