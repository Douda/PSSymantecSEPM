[CmdletBinding()]
param()

Describe 'Invoke-SeedHostGroups' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment

        InModuleScope PSSymantecSEPM {
            $script:configurationFilePath = Join-Path -Path 'TestDrive:' -ChildPath 'config.json'
            $script:credentialsFilePath   = Join-Path -Path 'TestDrive:' -ChildPath 'creds.xml'
            $script:accessTokenFilePath   = Join-Path -Path 'TestDrive:' -ChildPath 'token.xml'
        }

        $script:SeedScriptPath = Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath 'Scripts/Seed-HostGroups.ps1'
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context 'Tracer bullet' {
        BeforeAll {
            $fakeSession = New-TestSession -SkipCert

            Mock Invoke-SepmApi {
                if ($Method -eq 'GET') { return @() }
                return @{ id = 'new-hostgroup-id'; name = 'Corporate LAN' }
            }

            . $script:SeedScriptPath
        }

        It 'returns a state hashtable with HostGroupMap' {
            $State = @{ Force = $false; Session = (New-TestSession -SkipCert) }
            $output = Invoke-SeedHostGroups -State $State
            $output | Should -Not -BeNullOrEmpty
            $output -is [hashtable] | Should -BeTrue
            $output.ContainsKey('HostGroupMap') | Should -BeTrue
        }
    }

    Context 'Creates both host groups' {
        BeforeAll {
            $fakeSession = New-TestSession -SkipCert

            $script:hgList = [System.Collections.Generic.List[object]]::new()

            Mock Invoke-SepmApi {
                if ($Method -eq 'GET') {
                    return @{ content = $script:hgList.ToArray() }
                }
                if ($Method -eq 'POST') {
                    $bodyObj = $Body | ConvertFrom-Json
                    $id = "id-$($bodyObj.name -replace ' ','-')"
                    $script:hgList.Add(@{ name = $bodyObj.name; id = $id })
                    return $null
                }
                return $null
            }

            . $script:SeedScriptPath

            $State = @{ Force = $false; Session = $fakeSession }
            $script:result = Invoke-SeedHostGroups -State $State
        }

        It 'populates HostGroupMap with 2 entries' {
            $script:result.HostGroupMap.Count | Should -Be 2
        }

        It 'maps Corporate LAN to server ID' {
            $script:result.HostGroupMap['Corporate LAN'] | Should -Be 'id-Corporate-LAN'
        }

        It 'maps DMZ Servers to server ID' {
            $script:result.HostGroupMap['DMZ Servers'] | Should -Be 'id-DMZ-Servers'
        }
    }

    Context 'POST body includes correct host format' {
        BeforeAll {
            $fakeSession = New-TestSession -SkipCert

            $script:hgList = [System.Collections.Generic.List[object]]::new()
            $script:postBodies = @()

            Mock Invoke-SepmApi {
                if ($Method -eq 'GET') {
                    return @{ content = $script:hgList.ToArray() }
                }
                if ($Method -eq 'POST') {
                    $script:postBodies += $Body
                    $bodyObj = $Body | ConvertFrom-Json
                    $id = "id-$($bodyObj.name -replace ' ','-')"
                    $script:hgList.Add(@{ name = $bodyObj.name; id = $id })
                    return $null
                }
                return $null
            }

            . $script:SeedScriptPath

            $State = @{ Force = $false; Session = $fakeSession }
            $null = Invoke-SeedHostGroups -State $State
        }

        It 'POSTs exactly 2 host groups' {
            $script:postBodies.Count | Should -Be 2
        }

        It 'first POST contains name Corporate LAN' {
            $body = $script:postBodies[0] | ConvertFrom-Json
            $body.name | Should -Be 'Corporate LAN'
        }

        It 'Corporate LAN has 3 hosts' {
            $body = $script:postBodies[0] | ConvertFrom-Json
            $body.hosts.Count | Should -Be 3
        }

        It 'Corporate LAN host 1 is ipv4_subnet with ip and mask' {
            $body = $script:postBodies[0] | ConvertFrom-Json
            $host1 = $body.hosts[0]
            $host1.PSObject.Properties.Name -contains 'ipv4_subnet' | Should -BeTrue
            $host1.ipv4_subnet.ip | Should -Be '10.0.0.0'
            $host1.ipv4_subnet.mask | Should -Be '255.0.0.0'
        }

        It 'Corporate LAN host 2 is ipv4_subnet with ip and mask' {
            $body = $script:postBodies[0] | ConvertFrom-Json
            $host2 = $body.hosts[1]
            $host2.PSObject.Properties.Name -contains 'ipv4_subnet' | Should -BeTrue
            $host2.ipv4_subnet.ip | Should -Be '172.16.0.0'
            $host2.ipv4_subnet.mask | Should -Be '255.240.0.0'
        }

        It 'Corporate LAN host 3 is a single ip' {
            $body = $script:postBodies[0] | ConvertFrom-Json
            $host3 = $body.hosts[2]
            $host3.PSObject.Properties.Name -contains 'ip' | Should -BeTrue
            $host3.ip | Should -Be '192.168.1.1'
        }

        It 'DMZ Servers POST has 2 hosts' {
            $body = $script:postBodies[1] | ConvertFrom-Json
            $body.name | Should -Be 'DMZ Servers'
            $body.hosts.Count | Should -Be 2
        }

        It 'DMZ Servers host 1 is ipv4_subnet' {
            $body = $script:postBodies[1] | ConvertFrom-Json
            $host1 = $body.hosts[0]
            $host1.PSObject.Properties.Name -contains 'ipv4_subnet' | Should -BeTrue
            $host1.ipv4_subnet.ip | Should -Be '192.168.100.0'
            $host1.ipv4_subnet.mask | Should -Be '255.255.255.0'
        }

        It 'DMZ Servers host 2 is a single ip' {
            $body = $script:postBodies[1] | ConvertFrom-Json
            $host2 = $body.hosts[1]
            $host2.PSObject.Properties.Name -contains 'ip' | Should -BeTrue
            $host2.ip | Should -Be '10.0.0.100'
        }
    }

    Context 'Partial idempotency (some exist, some new)' {
        BeforeAll {
            $fakeSession = New-TestSession -SkipCert

            # Only Corporate LAN exists
            $script:hgList = [System.Collections.Generic.List[object]]::new()
            $script:hgList.Add(@{ name = 'Corporate LAN'; id = 'existing-corp-lan' })

            $script:postCalls = @()
            Mock Invoke-SepmApi {
                if ($Method -eq 'GET') {
                    return @{ content = $script:hgList.ToArray() }
                }
                if ($Method -eq 'POST') {
                    $script:postCalls += $Body
                    $bodyObj = $Body | ConvertFrom-Json
                    $id = "new-$($bodyObj.name -replace ' ','-')"
                    $script:hgList.Add(@{ name = $bodyObj.name; id = $id })
                    return $null
                }
                return $null
            }

            . $script:SeedScriptPath

            $State = @{ Force = $false; Session = $fakeSession }
            $script:result = Invoke-SeedHostGroups -State $State
        }

        It 'POSTs only missing host group (DMZ Servers)' {
            $script:postCalls.Count | Should -Be 1
            $body = $script:postCalls[0] | ConvertFrom-Json
            $body.name | Should -Be 'DMZ Servers'
        }

        It 'uses existing ID for Corporate LAN' {
            $script:result.HostGroupMap['Corporate LAN'] | Should -Be 'existing-corp-lan'
        }

        It 'assigns new ID for DMZ Servers' {
            $script:result.HostGroupMap['DMZ Servers'] | Should -Be 'new-DMZ-Servers'
        }
    }

    Context 'Force mode deletes and recreates' {
        BeforeAll {
            $fakeSession = New-TestSession -SkipCert

            # Both seed host groups already exist
            $script:hgList = [System.Collections.Generic.List[object]]::new()
            $script:hgList.Add(@{ name = 'Corporate LAN'; id = 'old-corp-lan' })
            $script:hgList.Add(@{ name = 'DMZ Servers'; id = 'old-dmz' })

            $script:deletedIds = @()
            $script:postCalls = @()
            Mock Invoke-SepmApi {
                if ($Method -eq 'GET') {
                    return @{ content = $script:hgList.ToArray() }
                }
                if ($Method -eq 'DELETE') {
                    $script:deletedIds += $Uri
                    # Simulate DELETE 500: return error string, do NOT remove from list
                    return 'Error: Internal Server Error'
                }
                if ($Method -eq 'POST') {
                    $script:postCalls += $Body
                    $bodyObj = $Body | ConvertFrom-Json
                    # Remove old entry with same name (simulating Force recreation)
                    $idx = 0..($script:hgList.Count - 1) | Where-Object { $script:hgList[$_].name -eq $bodyObj.name } | Select-Object -First 1
                    if ($null -ne $idx) { $script:hgList.RemoveAt($idx) }
                    $id = "new-$($bodyObj.name -replace ' ','-')"
                    $script:hgList.Add(@{ name = $bodyObj.name; id = $id })
                    return $null
                }
                return $null
            }

            . $script:SeedScriptPath

            $State = @{ Force = $true; Session = $fakeSession }
            $script:result = Invoke-SeedHostGroups -State $State
        }

        It 'attempts to delete existing seed host groups' {
            $script:deletedIds.Count | Should -Be 2
        }

        It 'recreates both host groups despite DELETE failure' {
            $script:postCalls.Count | Should -Be 2
        }

        It 'assigns new IDs after recreation' {
            $script:result.HostGroupMap['Corporate LAN'] | Should -Be 'new-Corporate-LAN'
            $script:result.HostGroupMap['DMZ Servers'] | Should -Be 'new-DMZ-Servers'
        }
    }

    Context 'State preservation' {
        BeforeAll {
            $fakeSession = New-TestSession -SkipCert

            $script:hgList = [System.Collections.Generic.List[object]]::new()
            Mock Invoke-SepmApi {
                if ($Method -eq 'GET') {
                    return @{ content = $script:hgList.ToArray() }
                }
                if ($Method -eq 'POST') {
                    $bodyObj = $Body | ConvertFrom-Json
                    $id = "id-$($bodyObj.name -replace ' ','-')"
                    $script:hgList.Add(@{ name = $bodyObj.name; id = $id })
                    return $null
                }
                return $null
            }

            . $script:SeedScriptPath

            $script:inputState = @{
                Force       = $false
                Session     = $fakeSession
                ExistingKey = 'preserved-value'
            }
            $script:result = Invoke-SeedHostGroups -State $script:inputState
        }

        It 'preserves existing state keys' {
            $script:result.ExistingKey | Should -Be 'preserved-value'
        }

        It 'adds HostGroupMap alongside existing keys' {
            $script:result.ContainsKey('HostGroupMap') | Should -BeTrue
            $script:result.ContainsKey('ExistingKey') | Should -BeTrue
        }
    }
}
