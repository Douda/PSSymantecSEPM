[CmdletBinding()]
param()

Describe 'Invoke-SeedAssignments' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment

        InModuleScope PSSymantecSEPM {
            $script:configurationFilePath = Join-Path -Path 'TestDrive:' -ChildPath 'config.json'
            $script:credentialsFilePath   = Join-Path -Path 'TestDrive:' -ChildPath 'creds.xml'
            $script:accessTokenFilePath   = Join-Path -Path 'TestDrive:' -ChildPath 'token.xml'
        }

        $script:SeedScriptPath = Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath 'Scripts/Seed-Assignments.ps1'
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context 'Tracer bullet' {
        BeforeAll {
            $fakeSession = New-TestSession -SkipCert

            Mock Invoke-SepmApi { param($Method, $Uri, $Session, $Body, $ContentType) }

            # Dot-source the seed function
            . $script:SeedScriptPath
        }

        It 'returns a state hashtable without errors' {
            $State = @{
                Force               = $false
                Session             = (New-TestSession -SkipCert)
                GroupMap            = @{}
                ExceptionPolicyMap  = @{}
                MEMPolicyMap        = @{}
                UpgradePolicyMap    = @{}
                TDADPolicyMap       = @{}
                FingerprintMap      = @{}
            }
            $output = Invoke-SeedAssignments -State $State
            $output | Should -Not -BeNullOrEmpty
            $output -is [hashtable] | Should -BeTrue
        }
    }

    Context 'Suffix pattern resolution against GroupMap' {
        BeforeAll {
            $fakeSession = New-TestSession -SkipCert

            $script:putCalls = @()
            Mock Invoke-SepmApi {
                param($Method, $Uri, $Session, $Body, $ContentType)
                if ($Method -eq 'PUT') {
                    $script:putCalls += [PSCustomObject]@{
                        Uri  = $Uri
                        Body = $Body
                    }
                }
            }

            . $script:SeedScriptPath
        }

        It 'matches suffix patterns against GroupMap keys' {
            $script:putCalls = @()
            $State = @{
                Force     = $false
                Session   = (New-TestSession -SkipCert)
                GroupMap  = @{
                    'My Company\EMEA\UK\London\Servers'      = 'g-london-serv'
                    'My Company\EMEA\UK\London\Workstations' = 'g-london-ws'
                    'My Company\EMEA\UK\Manchester\Servers'  = 'g-manch-serv'
                    'My Company\EMEA\Germany\Berlin\Servers' = 'g-berlin-serv'
                }
                ExceptionPolicyMap = @{
                    'Server Exceptions' = 'p-server-exc'
                }
                MEMPolicyMap        = @{}
                UpgradePolicyMap    = @{}
                TDADPolicyMap       = @{}
                FingerprintMap      = @{}
            }
            $null = Invoke-SeedAssignments -State $State

            # Should match all 3 Servers groups
            $script:putCalls.Count | Should -Be 3
        }
    }

    Context 'Flat Workstations exclusion' {
        BeforeAll {
            $fakeSession = New-TestSession -SkipCert

            $script:putCalls = @()
            Mock Invoke-SepmApi {
                param($Method, $Uri, $Session, $Body, $ContentType)
                if ($Method -eq 'PUT') {
                    $script:putCalls += [PSCustomObject]@{
                        Uri  = $Uri
                        Body = $Body
                    }
                }
            }

            . $script:SeedScriptPath
        }

        BeforeEach {
            $script:putCalls = @()
        }

        It 'skips Workstation groups that have subgroup children' {
            $State = @{
                Force    = $false
                Session  = (New-TestSession -SkipCert)
                GroupMap = @{
                    # London has HR Exception Machines subgroup
                    'My Company\EMEA\UK\London\Workstations'                = 'g-london-ws'
                    'My Company\EMEA\UK\London\Workstations\HR Exception Machines' = 'g-london-hr'
                    # Munich is flat (no subgroup)
                    'My Company\EMEA\Germany\Munich\Workstations'           = 'g-munich-ws'
                }
                ExceptionPolicyMap = @{
                    'Standard Workstation Exceptions' = 'p-std-exc'
                    'Developer Exceptions'            = 'p-dev-exc'
                }
                MEMPolicyMap     = @{
                    'Standard MEM' = 'p-std-mem'
                }
                UpgradePolicyMap = @{}
                TDADPolicyMap    = @{}
                FingerprintMap   = @{}
            }
            $null = Invoke-SeedAssignments -State $State

            # Munich flat Workstations: 2 entries (exceptions + mem, upgrade missing from map)
            # London HR Exception Machines: 2 entries (Developer Exceptions, Standard MEM, but Developer Exceptions maps to ExceptionPolicyMap — wait, HR Exception Machines maps to exceptions=Developer Exceptions, mem=Standard MEM)
            # With full data file: Munich WS gets exceptions + mem (2 calls), London HR gets exceptions + mem (2 calls) = 4 calls
            # But London HR has Developer Exceptions → ExceptionPolicyMap has it → 1 PUT
            # London HR has Standard MEM → MEMPolicyMap has it → 1 PUT
            # London WS (parent) excluded due to HR child → 0 PUTs for WS entries on London
            $script:putCalls.Count | Should -Be 4

            # London WS should NOT appear in any PUT URI
            $londonWsCalls = $script:putCalls | Where-Object { $_.Uri -match '/g-london-ws/' }
            $londonWsCalls | Should -BeNullOrEmpty

            # Munich WS should appear (flat)
            $munichCalls = $script:putCalls | Where-Object { $_.Uri -match '/g-munich-ws/' }
            $munichCalls.Count | Should -BeGreaterThan 0
        }
    }

    Context 'PUT calls have correct URI and body' {
        BeforeAll {
            $fakeSession = New-TestSession -SkipCert

            $script:putCalls = @()
            Mock Invoke-SepmApi {
                param($Method, $Uri, $Session, $Body, $ContentType)
                if ($Method -eq 'PUT') {
                    $script:putCalls += [PSCustomObject]@{
                        Uri  = $Uri
                        Body = $Body
                    }
                }
            }

            . $script:SeedScriptPath
        }

        BeforeEach {
            $script:putCalls = @()
        }

        It 'constructs correct PUT URI for policy assignments' {
            $State = @{
                Force    = $false
                Session  = (New-TestSession -SkipCert)
                GroupMap = @{
                    'My Company\EMEA\UK\London\Servers' = 'g-london-serv'
                }
                ExceptionPolicyMap = @{
                    'Server Exceptions' = 'p-server-exc'
                }
                MEMPolicyMap     = @{}
                UpgradePolicyMap = @{}
                TDADPolicyMap    = @{}
                FingerprintMap   = @{}
            }
            $null = Invoke-SeedAssignments -State $State

            $script:putCalls.Count | Should -Be 1
            $call = $script:putCalls[0]
            $call.Uri | Should -BeExactly 'https://FakeServer01:1234/sepm/api/v1/groups/g-london-serv/locations/default/policies/exceptions'
            $call.Body | Should -Not -BeNullOrEmpty

            $bodyObj = $call.Body | ConvertFrom-Json
            $bodyObj.id | Should -Be 'p-server-exc'
        }
    }

    Context 'Fingerprint assignments' {
        BeforeAll {
            $fakeSession = New-TestSession -SkipCert

            $script:putCalls = @()
            Mock Invoke-SepmApi {
                param($Method, $Uri, $Session, $Body, $ContentType)
                if ($Method -eq 'PUT') {
                    $script:putCalls += [PSCustomObject]@{
                        Uri  = $Uri
                        Body = $Body
                    }
                }
            }

            . $script:SeedScriptPath
        }

        BeforeEach {
            $script:putCalls = @()
        }

        It 'constructs correct PUT URI for fingerprint assignments' {
            $State = @{
                Force    = $false
                Session  = (New-TestSession -SkipCert)
                GroupMap = @{
                    'My Company\EMEA\Germany\Berlin\Workstations\Entrance Office' = 'g-berlin-ent'
                }
                ExceptionPolicyMap = @{}
                MEMPolicyMap       = @{}
                UpgradePolicyMap   = @{}
                TDADPolicyMap      = @{}
                FingerprintMap     = @{
                    'Known Malware Hashes' = 'fp-known-malware'
                }
            }
            # Data file doesn't have fingerprint entries yet, so we test via direct inspection
            # The suffix-match + fingerprint PUT logic is in the function
            # We just need the data file to have a fingerprint entry to trigger this path
            $null = Invoke-SeedAssignments -State $State

            # Full data file has *\Entrance Office fingerprint entry.
            # Our GroupMap has Entrance Office → expects 1 fingerprint PUT.
            $script:putCalls.Count | Should -Be 1
            $call = $script:putCalls[0]
            $call.Uri | Should -Match '/g-berlin-ent/system-lockdown/fingerprints/fp-known-malware'
        }

        It 'calls fingerprint endpoint with correct URI pattern' {
            # Directly invoke the PUT path with fingerprint data
            # Simulate what happens when an entry has policyType = 'fingerprint'
            $State = @{
                Force    = $false
                Session  = (New-TestSession -SkipCert)
                GroupMap = @{
                    'My Company\EMEA\Germany\Berlin\Workstations\Entrance Office' = 'g-berlin-ent'
                }
                ExceptionPolicyMap = @{}
                MEMPolicyMap       = @{}
                UpgradePolicyMap   = @{}
                TDADPolicyMap      = @{}
                FingerprintMap     = @{
                    'Known Malware Hashes' = 'fp-known-malware'
                }
            }

            # We need a fingerprint entry in the data file for this to work.
            # The current test data doesn't have one. Add a fingerprint entry
            # to the data file temporarily.
            $tempData = @{
                Assignments = @(
                    @{
                        groupPath       = '*\Entrance Office'
                        policyType      = 'fingerprint'
                        fingerprintName = 'Known Malware Hashes'
                    }
                )
            }

            # Mock Import-PowerShellDataFile to return our temp data
            Mock Import-PowerShellDataFile { return $tempData }

            $null = Invoke-SeedAssignments -State $State

            $script:putCalls.Count | Should -Be 1
            $call = $script:putCalls[0]
            $call.Uri | Should -BeExactly 'https://FakeServer01:1234/sepm/api/v1/groups/g-berlin-ent/system-lockdown/fingerprints/fp-known-malware'
            $call.Body | Should -BeNullOrEmpty
        }
    }

    Context 'Warning on unresolvable references' {
        BeforeAll {
            $fakeSession = New-TestSession -SkipCert

            Mock Invoke-SepmApi { param($Method, $Uri, $Session, $Body, $ContentType) }

            . $script:SeedScriptPath
        }

        It 'warns when no groups match the suffix pattern' {
            $State = @{
                Force              = $false
                Session            = (New-TestSession -SkipCert)
                GroupMap           = @{}
                ExceptionPolicyMap = @{}
                MEMPolicyMap       = @{}
                UpgradePolicyMap   = @{}
                TDADPolicyMap      = @{}
                FingerprintMap     = @{}
            }

            $warnings = @()
            $null = Invoke-SeedAssignments -State $State -WarningVariable warnings -WarningAction SilentlyContinue

            ($warnings -match 'No groups matched suffix pattern') | Should -Not -BeNullOrEmpty
        }

        It 'warns when policy name is not found in the policy map' {
            $State = @{
                Force    = $false
                Session  = (New-TestSession -SkipCert)
                GroupMap = @{
                    'My Company\EMEA\UK\London\Servers' = 'g-london-serv'
                }
                ExceptionPolicyMap = @{}
                MEMPolicyMap       = @{}
                UpgradePolicyMap   = @{}
                TDADPolicyMap      = @{}
                FingerprintMap     = @{}
            }

            $warnings = @()
            $null = Invoke-SeedAssignments -State $State -WarningVariable warnings -WarningAction SilentlyContinue

            ($warnings -match 'Policy .* not found') | Should -Not -BeNullOrEmpty
        }

        It 'warns when fingerprint name is not found' {
            $tempData = @{
                Assignments = @(
                    @{
                        groupPath       = '*\Entrance Office'
                        policyType      = 'fingerprint'
                        fingerprintName = 'MissingFingerprint'
                    }
                )
            }
            Mock Import-PowerShellDataFile { return $tempData }

            $State = @{
                Force              = $false
                Session            = (New-TestSession -SkipCert)
                GroupMap           = @{
                    'My Company\EMEA\Germany\Berlin\Workstations\Entrance Office' = 'g-berlin-ent'
                }
                ExceptionPolicyMap = @{}
                MEMPolicyMap       = @{}
                UpgradePolicyMap   = @{}
                TDADPolicyMap      = @{}
                FingerprintMap     = @{}
            }

            $warnings = @()
            $null = Invoke-SeedAssignments -State $State -WarningVariable warnings -WarningAction SilentlyContinue

            ($warnings -match 'Fingerprint .* not found') | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Idempotency' {
        BeforeAll {
            $fakeSession = New-TestSession -SkipCert

            $script:putCalls = @()
            Mock Invoke-SepmApi {
                param($Method, $Uri, $Session, $Body, $ContentType)
                if ($Method -eq 'PUT') {
                    $script:putCalls += [PSCustomObject]@{
                        Uri  = $Uri
                        Body = $Body
                    }
                }
            }

            . $script:SeedScriptPath
        }

        BeforeEach {
            $script:putCalls = @()
        }

        It 'produces identical PUT calls on re-run' {
            $State = @{
                Force    = $false
                Session  = (New-TestSession -SkipCert)
                GroupMap = @{
                    'My Company\EMEA\UK\London\Servers'      = 'g-london-serv'
                    'My Company\EMEA\UK\Manchester\Servers'  = 'g-manch-serv'
                    'My Company\EMEA\Germany\Berlin\Servers' = 'g-berlin-serv'
                }
                ExceptionPolicyMap = @{
                    'Server Exceptions' = 'p-server-exc'
                }
                MEMPolicyMap     = @{}
                UpgradePolicyMap = @{}
                TDADPolicyMap    = @{}
                FingerprintMap   = @{}
            }

            # First run
            $null = Invoke-SeedAssignments -State $State
            $firstRunUris = $script:putCalls | ForEach-Object { $_.Uri }

            # Second run
            $script:putCalls = @()
            $null = Invoke-SeedAssignments -State $State
            $secondRunUris = $script:putCalls | ForEach-Object { $_.Uri }

            # Both runs should produce the same calls
            $firstRunUris.Count | Should -Be $secondRunUris.Count
            # URI sets should match (order may differ with hashtable enumeration)
            $diff = Compare-Object $firstRunUris $secondRunUris
            $diff | Should -BeNullOrEmpty
        }
    }
}
