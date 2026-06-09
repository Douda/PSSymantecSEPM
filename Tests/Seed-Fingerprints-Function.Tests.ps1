[CmdletBinding()]
param()

Describe 'Invoke-SeedFingerprints' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment

        $script:SeedScriptPath = Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath 'Scripts/Seed-Fingerprints.ps1'
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context 'Tracer bullet' {
        BeforeAll {
            $fakeSession = New-TestSession -SkipCert

            Mock Invoke-SepmApi {
                if ($Method -eq 'GET' -and $Uri -match '/domains$') {
                    return @(@{ id = 'default-domain-id'; name = 'Default' })
                }
                if ($Method -eq 'GET' -and $Uri -match 'fingerprints\?name=') {
                    return $null
                }
                if ($Method -eq 'POST') {
                    return @{ id = 'new-fingerprint-id'; name = 'Known Malware Hashes' }
                }
                return $null
            }

            . $script:SeedScriptPath
        }

        It 'returns a state hashtable with FingerprintMap' {
            $State = @{ Force = $false; Session = (New-TestSession -SkipCert) }
            $output = Invoke-SeedFingerprints -State $State
            $output | Should -Not -BeNullOrEmpty
            $output -is [hashtable] | Should -BeTrue
            $output.ContainsKey('FingerprintMap') | Should -BeTrue
        }
    }

    Context 'Creates both fingerprint lists' {
        BeforeAll {
            $fakeSession = New-TestSession -SkipCert

            $script:fpLookup = [System.Collections.Generic.List[object]]::new()
            $script:postCalls = @()

            Mock Invoke-SepmApi {
                if ($Method -eq 'GET' -and $Uri -match '/domains$') {
                    return @(@{ id = 'default-domain-id'; name = 'Default' })
                }
                if ($Method -eq 'GET' -and $Uri -match 'fingerprints\?name=') {
                    $nameMatch = [regex]::Match($Uri, 'name=([^&]+)')
                    if ($nameMatch.Success) {
                        $name = [System.Uri]::UnescapeDataString($nameMatch.Groups[1].Value)
                        foreach ($fp in $script:fpLookup) {
                            if ($fp.name -eq $name) { return $fp }
                        }
                    }
                    return $null
                }
                if ($Method -eq 'POST') {
                    $script:postCalls += $Body
                    $bodyObj = $Body | ConvertFrom-Json
                    $id = 'id-' + ($bodyObj.name -replace '[^a-zA-Z0-9]', '-')
                    $script:fpLookup.Add(@{ name = $bodyObj.name; id = $id })
                    return @{ id = $id; name = $bodyObj.name }
                }
                return $null
            }

            . $script:SeedScriptPath

            $State = @{ Force = $false; Session = $fakeSession }
            $script:result = Invoke-SeedFingerprints -State $State
        }

        It 'populates FingerprintMap with 2 entries' {
            $script:result.FingerprintMap.Count | Should -Be 2
        }

        It 'maps Known Malware Hashes to server ID' {
            $script:result.FingerprintMap['Known Malware Hashes'] | Should -Be 'id-Known-Malware-Hashes'
        }

        It 'maps Approved Binaries to server ID' {
            $script:result.FingerprintMap['Approved Binaries'] | Should -Be 'id-Approved-Binaries'
        }
    }

    Context 'POST body includes correct hash data' {
        BeforeAll {
            $fakeSession = New-TestSession -SkipCert

            $script:fpLookup = [System.Collections.Generic.List[object]]::new()
            $script:postBodies = @()

            Mock Invoke-SepmApi {
                if ($Method -eq 'GET' -and $Uri -match '/domains$') {
                    return @(@{ id = 'default-domain-id'; name = 'Default' })
                }
                if ($Method -eq 'GET' -and $Uri -match 'fingerprints\?name=') {
                    return $null
                }
                if ($Method -eq 'POST') {
                    $script:postBodies += $Body
                    $bodyObj = $Body | ConvertFrom-Json
                    $id = 'id-' + ($bodyObj.name -replace '[^a-zA-Z0-9]', '-')
                    $script:fpLookup.Add(@{ name = $bodyObj.name; id = $id })
                    return @{ id = $id; name = $bodyObj.name }
                }
                return $null
            }

            . $script:SeedScriptPath

            $State = @{ Force = $false; Session = $fakeSession }
            $null = Invoke-SeedFingerprints -State $State
        }

        It 'POSTs exactly 2 fingerprint lists' {
            $script:postBodies.Count | Should -Be 2
        }

        It 'Known Malware Hashes body has name and description' {
            $body = $script:postBodies[0] | ConvertFrom-Json
            $body.name | Should -Be 'Known Malware Hashes'
            $body.description | Should -Be 'Seed data — simulated malware hashes'
            $body.hashType | Should -Be 'SHA256'
        }

        It 'Known Malware Hashes has 5 SHA256 hashes' {
            $body = $script:postBodies[0] | ConvertFrom-Json
            $body.data.Count | Should -Be 5
        }

        It 'Known Malware Hashes data entries are 64-char hex strings' {
            $body = $script:postBodies[0] | ConvertFrom-Json
            foreach ($hash in $body.data) {
                $hash.Length | Should -Be 64
                $hash -match '^[0-9a-fA-F]{64}$' | Should -BeTrue
            }
        }

        It 'Approved Binaries body has name and description' {
            $body = $script:postBodies[1] | ConvertFrom-Json
            $body.name | Should -Be 'Approved Binaries'
            $body.description | Should -Be 'Seed data — simulated approved binaries'
            $body.hashType | Should -Be 'SHA256'
        }

        It 'Approved Binaries has 3 SHA256 hashes' {
            $body = $script:postBodies[1] | ConvertFrom-Json
            $body.data.Count | Should -Be 3
        }

        It 'Approved Binaries data entries are 64-char hex strings' {
            $body = $script:postBodies[1] | ConvertFrom-Json
            foreach ($hash in $body.data) {
                $hash.Length | Should -Be 64
                $hash -match '^[0-9a-fA-F]{64}$' | Should -BeTrue
            }
        }
    }

    Context 'domainId injected from runtime Default domain lookup' {
        BeforeAll {
            $fakeSession = New-TestSession -SkipCert

            $script:fpLookup = [System.Collections.Generic.List[object]]::new()
            $script:postBodies = @()

            Mock Invoke-SepmApi {
                if ($Method -eq 'GET' -and $Uri -match '/domains$') {
                    return @(
                        @{ id = 'other-domain-id'; name = 'Other' },
                        @{ id = 'runtime-default-id'; name = 'Default' },
                        @{ id = 'extra-domain-id'; name = 'Extra' }
                    )
                }
                if ($Method -eq 'GET' -and $Uri -match 'fingerprints\?name=') {
                    return $null
                }
                if ($Method -eq 'POST') {
                    $script:postBodies += $Body
                    $bodyObj = $Body | ConvertFrom-Json
                    $id = 'id-' + ($bodyObj.name -replace '[^a-zA-Z0-9]', '-')
                    $script:fpLookup.Add(@{ name = $bodyObj.name; id = $id })
                    return @{ id = $id; name = $bodyObj.name }
                }
                return $null
            }

            . $script:SeedScriptPath

            $State = @{ Force = $false; Session = $fakeSession }
            $null = Invoke-SeedFingerprints -State $State
        }

        It 'uses Default domain ID in POST body' {
            $body = $script:postBodies[0] | ConvertFrom-Json
            $body.domainId | Should -Be 'runtime-default-id'
        }

        It 'uses same domainId for both fingerprint lists' {
            $body1 = $script:postBodies[0] | ConvertFrom-Json
            $body2 = $script:postBodies[1] | ConvertFrom-Json
            $body1.domainId | Should -Be 'runtime-default-id'
            $body2.domainId | Should -Be 'runtime-default-id'
        }
    }

    Context 'Partial idempotency (some exist, some new)' {
        BeforeAll {
            $fakeSession = New-TestSession -SkipCert

            # Known Malware Hashes already exists
            $script:fpLookup = [System.Collections.Generic.List[object]]::new()
            $script:fpLookup.Add(@{ name = 'Known Malware Hashes'; id = 'existing-malware-id' })

            $script:postCalls = @()
            Mock Invoke-SepmApi {
                if ($Method -eq 'GET' -and $Uri -match '/domains$') {
                    return @(@{ id = 'default-domain-id'; name = 'Default' })
                }
                if ($Method -eq 'GET' -and $Uri -match 'fingerprints\?name=') {
                    $nameMatch = [regex]::Match($Uri, 'name=([^&]+)')
                    if ($nameMatch.Success) {
                        $name = [System.Uri]::UnescapeDataString($nameMatch.Groups[1].Value)
                        foreach ($fp in $script:fpLookup) {
                            if ($fp.name -eq $name) { return $fp }
                        }
                    }
                    return $null
                }
                if ($Method -eq 'POST') {
                    $script:postCalls += $Body
                    $bodyObj = $Body | ConvertFrom-Json
                    $id = 'new-' + ($bodyObj.name -replace '[^a-zA-Z0-9]', '-')
                    $script:fpLookup.Add(@{ name = $bodyObj.name; id = $id })
                    return @{ id = $id; name = $bodyObj.name }
                }
                return $null
            }

            . $script:SeedScriptPath

            $State = @{ Force = $false; Session = $fakeSession }
            $script:result = Invoke-SeedFingerprints -State $State
        }

        It 'POSTs only missing fingerprint list (Approved Binaries)' {
            $script:postCalls.Count | Should -Be 1
            $body = $script:postCalls[0] | ConvertFrom-Json
            $body.name | Should -Be 'Approved Binaries'
        }

        It 'uses existing ID for Known Malware Hashes' {
            $script:result.FingerprintMap['Known Malware Hashes'] | Should -Be 'existing-malware-id'
        }

        It 'assigns new ID for Approved Binaries' {
            $script:result.FingerprintMap['Approved Binaries'] | Should -Be 'new-Approved-Binaries'
        }
    }

    Context 'Force mode deletes and recreates' {
        BeforeAll {
            $fakeSession = New-TestSession -SkipCert

            # Both seed fingerprint lists already exist
            $script:fpLookup = [System.Collections.Generic.List[object]]::new()
            $script:fpLookup.Add(@{ name = 'Known Malware Hashes'; id = 'old-malware-id' })
            $script:fpLookup.Add(@{ name = 'Approved Binaries'; id = 'old-binaries-id' })

            $script:deletedIds = @()
            $script:postCalls = @()
            Mock Invoke-SepmApi {
                if ($Method -eq 'GET' -and $Uri -match '/domains$') {
                    return @(@{ id = 'default-domain-id'; name = 'Default' })
                }
                if ($Method -eq 'GET' -and $Uri -match 'fingerprints\?name=') {
                    $nameMatch = [regex]::Match($Uri, 'name=([^&]+)')
                    if ($nameMatch.Success) {
                        $name = [System.Uri]::UnescapeDataString($nameMatch.Groups[1].Value)
                        foreach ($fp in $script:fpLookup) {
                            if ($fp.name -eq $name) { return $fp }
                        }
                    }
                    return $null
                }
                if ($Method -eq 'DELETE') {
                    $script:deletedIds += $Uri
                    return 'Error: Internal Server Error'
                }
                if ($Method -eq 'POST') {
                    $script:postCalls += $Body
                    $bodyObj = $Body | ConvertFrom-Json
                    # Remove old entry with same name (simulating Force recreation)
                    $idx = 0..($script:fpLookup.Count - 1) | Where-Object { $script:fpLookup[$_].name -eq $bodyObj.name } | Select-Object -First 1
                    if ($null -ne $idx) { $script:fpLookup.RemoveAt($idx) }
                    $id = 'new-' + ($bodyObj.name -replace '[^a-zA-Z0-9]', '-')
                    $script:fpLookup.Add(@{ name = $bodyObj.name; id = $id })
                    return @{ id = $id; name = $bodyObj.name }
                }
                return $null
            }

            . $script:SeedScriptPath

            $State = @{ Force = $true; Session = $fakeSession }
            $script:result = Invoke-SeedFingerprints -State $State
        }

        It 'attempts to delete existing seed fingerprint lists' {
            $script:deletedIds.Count | Should -Be 2
        }

        It 'recreates both fingerprint lists despite DELETE failure' {
            $script:postCalls.Count | Should -Be 2
        }

        It 'assigns new IDs after recreation' {
            $script:result.FingerprintMap['Known Malware Hashes'] | Should -Be 'new-Known-Malware-Hashes'
            $script:result.FingerprintMap['Approved Binaries'] | Should -Be 'new-Approved-Binaries'
        }
    }

    Context 'State preservation' {
        BeforeAll {
            $fakeSession = New-TestSession -SkipCert

            $script:fpLookup = [System.Collections.Generic.List[object]]::new()
            Mock Invoke-SepmApi {
                if ($Method -eq 'GET' -and $Uri -match '/domains$') {
                    return @(@{ id = 'default-domain-id'; name = 'Default' })
                }
                if ($Method -eq 'GET' -and $Uri -match 'fingerprints\?name=') {
                    return $null
                }
                if ($Method -eq 'POST') {
                    $bodyObj = $Body | ConvertFrom-Json
                    $id = 'id-' + ($bodyObj.name -replace '[^a-zA-Z0-9]', '-')
                    $script:fpLookup.Add(@{ name = $bodyObj.name; id = $id })
                    return @{ id = $id; name = $bodyObj.name }
                }
                return $null
            }

            . $script:SeedScriptPath

            $script:inputState = @{
                Force       = $false
                Session     = $fakeSession
                ExistingKey = 'preserved-value'
            }
            $script:result = Invoke-SeedFingerprints -State $script:inputState
        }

        It 'preserves existing state keys' {
            $script:result.ExistingKey | Should -Be 'preserved-value'
        }

        It 'adds FingerprintMap alongside existing keys' {
            $script:result.ContainsKey('FingerprintMap') | Should -BeTrue
            $script:result.ContainsKey('ExistingKey') | Should -BeTrue
        }
    }
}
