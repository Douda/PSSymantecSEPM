[CmdletBinding()]
param()

Describe 'Invoke-SeedGroups' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment

        InModuleScope PSSymantecSEPM {
            $script:configurationFilePath = Join-Path -Path 'TestDrive:' -ChildPath 'config.json'
            $script:credentialsFilePath   = Join-Path -Path 'TestDrive:' -ChildPath 'creds.xml'
            $script:accessTokenFilePath   = Join-Path -Path 'TestDrive:' -ChildPath 'token.xml'
        }

        $script:SeedScriptPath = Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath 'Scripts/Seed-Groups.ps1'
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context 'Tracer bullet' {
        BeforeAll {
            Mock Get-SEPMGroups { return @() }
            Mock New-SEPMGroup {
                return @{ id = 'fake-id'; name = $GroupName; fullPathName = "$ParentGroup\$GroupName" }
            }
            . $script:SeedScriptPath
        }

        It 'returns a state hashtable with GroupMap' {
            $State = @{ Force = $false }
            $output = Invoke-SeedGroups -State $State
            $output | Should -Not -BeNullOrEmpty
            $output -is [hashtable] | Should -BeTrue
            $output.ContainsKey('GroupMap') | Should -BeTrue
        }
    }

    Context 'Top-level region creation' {
        BeforeAll {
            $fakeSession = New-TestSession -SkipCert

            Mock Get-SEPMGroups {
                return @(
                    [PSCustomObject]@{ id = 'mc-id'; name = 'My Company'; fullPathName = 'My Company' },
                    [PSCustomObject]@{ id = 'def-id'; name = 'Default Group'; fullPathName = 'My Company\Default Group' }
                )
            }

            $script:createCalls = @()
            Mock New-SEPMGroup {
                $script:createCalls += [PSCustomObject]@{
                    GroupName         = $GroupName
                    ParentGroup       = $ParentGroup
                    EnabledInheritance = $EnabledInheritance.IsPresent
                    Description       = $Description
                }
                return @{ id = "id-$GroupName"; name = $GroupName; fullPathName = "$ParentGroup\$GroupName" }
            }
            Mock Invoke-SepmApi { param($Method, $Uri, $Session, $Body, $ContentType) }

            . $script:SeedScriptPath

            $State = @{ Force = $false }
            $script:result = Invoke-SeedGroups -State $State
        }

        It 'creates 3 regions under My Company' {
            ($script:createCalls | Where-Object { $_.ParentGroup -eq 'My Company' }).Count | Should -Be 3
        }

        It 'creates EMEA region' {
            $emea = $script:createCalls | Where-Object { $_.GroupName -eq 'EMEA' }
            ($emea | Should -Not -BeNullOrEmpty)
            $emea.ParentGroup | Should -Be 'My Company'
            $emea.EnabledInheritance | Should -BeTrue
            $emea.Description | Should -Be 'Region - EMEA'
        }

        It 'creates NA region' {
            $na = $script:createCalls | Where-Object { $_.GroupName -eq 'NA' }
            ($na | Should -Not -BeNullOrEmpty)
            $na.ParentGroup | Should -Be 'My Company'
            $na.EnabledInheritance | Should -BeTrue
        }

        It 'creates APJ region' {
            $apj = $script:createCalls | Where-Object { $_.GroupName -eq 'APJ' }
            ($apj | Should -Not -BeNullOrEmpty)
            $apj.ParentGroup | Should -Be 'My Company'
            $apj.EnabledInheritance | Should -BeTrue
        }

        It 'populates GroupMap with region entries' {
            $script:result.GroupMap['My Company\EMEA'] | Should -Be 'id-EMEA'
            $script:result.GroupMap['My Company\NA']   | Should -Be 'id-NA'
            $script:result.GroupMap['My Company\APJ']  | Should -Be 'id-APJ'
        }
    }

    Context 'Full hierarchy creation' {
        BeforeAll {
            # My Company + Default Group exist, nothing else
            Mock Get-SEPMGroups {
                return @(
                    [PSCustomObject]@{ id = 'mc-id'; name = 'My Company'; fullPathName = 'My Company' },
                    [PSCustomObject]@{ id = 'def-id'; name = 'Default Group'; fullPathName = 'My Company\Default Group' }
                )
            }

            $script:createCalls = @()
            Mock New-SEPMGroup {
                $script:createCalls += [PSCustomObject]@{
                    GroupName         = $GroupName
                    ParentGroup       = $ParentGroup
                    EnabledInheritance = $EnabledInheritance.IsPresent
                    Description       = $Description
                }
                return @{ id = "id-$GroupName"; name = $GroupName; fullPathName = "$ParentGroup\$GroupName" }
            }
            Mock Invoke-SepmApi { param($Method, $Uri, $Session, $Body, $ContentType) }

            . $script:SeedScriptPath

            $State = @{ Force = $false }
            $script:result = Invoke-SeedGroups -State $State
        }

        It 'creates all 126 groups (108 hashtable nodes + 18 string subgroups)' {
            $script:createCalls.Count | Should -Be 126
        }

        It 'creates a deep leaf at expected path' {
            $londonServers = $script:createCalls | Where-Object {
                $_.GroupName -eq 'Servers' -and $_.ParentGroup -eq 'My Company\EMEA\UK\London'
            }
            ($londonServers | Should -Not -BeNullOrEmpty)
        }

        It 'creates a Workstation subgroup' {
            $hrMachines = $script:createCalls | Where-Object {
                $_.GroupName -eq 'HR Exception Machines' -and $_.ParentGroup -eq 'My Company\APJ\Japan\Tokyo\Workstations'
            }
            ($hrMachines | Should -Not -BeNullOrEmpty)
        }

        It 'GroupMap contains deep paths' {
            $script:result.GroupMap['My Company\NA\US\New York\Servers'] | Should -Be 'id-Servers'
            $script:result.GroupMap['My Company\EMEA\France\Paris\Workstations\Developers'] | Should -Be 'id-Developers'
        }

        It 'creates all expected region names' {
            $regionNames = ($script:createCalls | Where-Object { $_.ParentGroup -eq 'My Company' }).GroupName
            $regionNames | Should -Contain 'EMEA'
            $regionNames | Should -Contain 'NA'
            $regionNames | Should -Contain 'APJ'
        }

        It 'creates all 15 countries' {
            $countryCalls = $script:createCalls | Where-Object {
                $_.ParentGroup -match '^My Company\\(EMEA|NA|APJ)$'
            }
            $countryCalls.Count | Should -Be 15
        }

        It 'creates all 30 cities' {
            $cityCalls = $script:createCalls | Where-Object {
                $_.ParentGroup -match '^My Company\\(EMEA|NA|APJ)\\[^\\]+$'
            }
            $cityCalls.Count | Should -Be 30
        }
    }

    Context 'Idempotency' {
        BeforeAll {
            # Mock Get-SEPMGroups to act as if ALL seed groups already exist
            Mock Get-SEPMGroups {
                # Build existing entries on-the-fly for all seed paths
                $seedDir = Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath 'Source/Seed'
                $data = Import-PowerShellDataFile -Path (Join-Path -Path $seedDir -ChildPath 'Groups.psd1') -ErrorAction Stop

                $results = [System.Collections.Generic.List[object]]::new()
                $results.Add([PSCustomObject]@{ id = 'mc-id'; name = 'My Company'; fullPathName = 'My Company' })
                $results.Add([PSCustomObject]@{ id = 'def-id'; name = 'Default Group'; fullPathName = 'My Company\Default Group' })

                function _AddPaths {
                    param($Nodes, [string]$ParentFullPath)
                    foreach ($node in $Nodes) {
                        if ($node -is [string]) {
                            $fp = "$ParentFullPath\$node"
                            $results.Add([PSCustomObject]@{ id = "existing-$fp"; name = $node; fullPathName = $fp })
                        } else {
                            $fp = "$ParentFullPath\$($node.Name)"
                            $results.Add([PSCustomObject]@{ id = "existing-$fp"; name = $node.Name; fullPathName = $fp })
                            if ($node.ContainsKey('Children') -and $node.Children) {
                                _AddPaths -Nodes $node.Children -ParentFullPath $fp
                            }
                        }
                    }
                }
                _AddPaths -Nodes $data.Groups -ParentFullPath 'My Company'
                return $results.ToArray()
            }

            $script:createCalls = @()
            Mock New-SEPMGroup {
                $script:createCalls += [PSCustomObject]@{
                    GroupName  = $GroupName
                    ParentGroup = $ParentGroup
                }
                return @{ id = "new-$GroupName"; name = $GroupName; fullPathName = "$ParentGroup\$GroupName" }
            }
            Mock Invoke-SepmApi { param($Method, $Uri, $Session, $Body, $ContentType) }

            . $script:SeedScriptPath

            $State = @{ Force = $false }
            $script:result = Invoke-SeedGroups -State $State
        }

        It 'does not create any groups (all already exist)' {
            $script:createCalls.Count | Should -Be 0
        }

        It 'still populates GroupMap with existing IDs' {
            $script:result.GroupMap.Count | Should -Be 126
            $script:result.GroupMap['My Company\EMEA'] | Should -Be 'existing-My Company\EMEA'
            $script:result.GroupMap['My Company\NA\US\New York\Servers'] | Should -Be 'existing-My Company\NA\US\New York\Servers'
        }
    }

    Context 'Inheritance rules' {
        BeforeAll {
            Mock Get-SEPMGroups {
                return @(
                    [PSCustomObject]@{ id = 'mc-id'; name = 'My Company'; fullPathName = 'My Company' },
                    [PSCustomObject]@{ id = 'def-id'; name = 'Default Group'; fullPathName = 'My Company\Default Group' }
                )
            }

            $script:createCalls = @()
            Mock New-SEPMGroup {
                $script:createCalls += [PSCustomObject]@{
                    GroupName         = $GroupName
                    ParentGroup       = $ParentGroup
                    EnabledInheritance = $EnabledInheritance.IsPresent
                    Description       = $Description
                }
                return @{ id = "id-$GroupName"; name = $GroupName; fullPathName = "$ParentGroup\$GroupName" }
            }
            Mock Invoke-SepmApi { param($Method, $Uri, $Session, $Body, $ContentType) }

            . $script:SeedScriptPath

            $State = @{ Force = $false }
            $null = Invoke-SeedGroups -State $State
        }

        It 'containers (regions, countries, cities) have inheritance enabled' {
            $containers = $script:createCalls | Where-Object {
                $_.GroupName -in @('EMEA', 'NA', 'APJ', 'UK', 'US', 'Japan', 'London', 'Tokyo', 'Paris')
            }
            foreach ($c in $containers) {
                $c.EnabledInheritance | Should -BeTrue -Because "$($c.GroupName) under $($c.ParentGroup) should inherit"
            }
        }

        It 'leaf groups (Servers) do NOT have inheritance' {
            $leafServers = $script:createCalls | Where-Object { $_.GroupName -eq 'Servers' }
            foreach ($s in $leafServers) {
                $s.EnabledInheritance | Should -BeFalse -Because "Servers under $($s.ParentGroup) should not inherit"
            }
        }

        It 'workstation subgroups do NOT have inheritance' {
            $subgroups = $script:createCalls | Where-Object {
                $_.GroupName -in @('HR Exception Machines', 'Small Office', 'Entrance Office', 'Developers', 'Executives')
            }
            foreach ($sg in $subgroups) {
                $sg.EnabledInheritance | Should -BeFalse -Because "$($sg.GroupName) subgroup should not inherit"
            }
        }
    }

    Context 'Descriptions' {
        BeforeAll {
            Mock Get-SEPMGroups {
                return @(
                    [PSCustomObject]@{ id = 'mc-id'; name = 'My Company'; fullPathName = 'My Company' },
                    [PSCustomObject]@{ id = 'def-id'; name = 'Default Group'; fullPathName = 'My Company\Default Group' }
                )
            }

            $script:createCalls = @()
            Mock New-SEPMGroup {
                $script:createCalls += [PSCustomObject]@{
                    GroupName   = $GroupName
                    Description = $Description
                }
                return @{ id = "id-$GroupName"; name = $GroupName; fullPathName = "$ParentGroup\$GroupName" }
            }
            Mock Invoke-SepmApi { param($Method, $Uri, $Session, $Body, $ContentType) }

            . $script:SeedScriptPath

            $State = @{ Force = $false }
            $null = Invoke-SeedGroups -State $State
        }

        It 'every created group has a non-empty description' {
            foreach ($call in $script:createCalls) {
                $call.Description | Should -Not -BeNullOrEmpty -Because "$($call.GroupName) must have a description"
            }
        }

        It 'region descriptions follow formula' {
            $emea = $script:createCalls | Where-Object { $_.GroupName -eq 'EMEA' }
            $emea.Description | Should -Be 'Region - EMEA'
        }

        It 'country descriptions follow formula' {
            $uk = $script:createCalls | Where-Object { $_.GroupName -eq 'UK' }
            $uk.Description | Should -Be 'Country - UK'
        }

        It 'city descriptions follow formula' {
            $london = $script:createCalls | Where-Object { $_.GroupName -eq 'London' }
            $london.Description | Should -Be 'City - London'
        }

        It 'leaf descriptions follow formula' {
            $servers = $script:createCalls | Where-Object { $_.GroupName -eq 'Servers' } | Select-Object -First 1
            $servers.Description | Should -Be 'Leaf - Servers'
        }
    }

    Context 'Force reset' {
        BeforeAll {
            # Pre-populate: My Company + Default Group + all 126 seed groups exist
            $seedDir = Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath 'Source/Seed'
            $data = Import-PowerShellDataFile -Path (Join-Path -Path $seedDir -ChildPath 'Groups.psd1') -ErrorAction Stop

            $results = [System.Collections.Generic.List[object]]::new()
            $results.Add([PSCustomObject]@{ id = 'mc-id'; name = 'My Company'; fullPathName = 'My Company' })
            $results.Add([PSCustomObject]@{ id = 'def-id'; name = 'Default Group'; fullPathName = 'My Company\Default Group' })
            function _AddPaths {
                param($Nodes, [string]$ParentFullPath)
                foreach ($node in $Nodes) {
                    if ($node -is [string]) {
                        $fp = "$ParentFullPath\$node"
                        $results.Add([PSCustomObject]@{ id = "existing-$fp"; name = $node; fullPathName = $fp })
                    } else {
                        $fp = "$ParentFullPath\$($node.Name)"
                        $results.Add([PSCustomObject]@{ id = "existing-$fp"; name = $node.Name; fullPathName = $fp })
                        if ($node.ContainsKey('Children') -and $node.Children) {
                            _AddPaths -Nodes $node.Children -ParentFullPath $fp
                        }
                    }
                }
            }
            _AddPaths -Nodes $data.Groups -ParentFullPath 'My Company'
            $existingGroups = $results.ToArray()

            $script:getGroupsCalls = 0
            Mock Get-SEPMGroups {
                if ($script:getGroupsCalls -gt 0) {
                    # After deletion: only My Company and Default Group remain
                    return @(
                        [PSCustomObject]@{ id = 'mc-id'; name = 'My Company'; fullPathName = 'My Company' },
                        [PSCustomObject]@{ id = 'def-id'; name = 'Default Group'; fullPathName = 'My Company\Default Group' }
                    )
                }
                $script:getGroupsCalls++
                return $existingGroups
            }

            $script:deleteCalls = @()
            Mock Remove-SEPMGroup {
                $script:deleteCalls += [PSCustomObject]@{
                    GroupName   = $GroupName
                    ParentGroup = $ParentGroup
                }
            }

            $script:createCalls = @()
            Mock New-SEPMGroup {
                $script:createCalls += [PSCustomObject]@{
                    GroupName  = $GroupName
                    ParentGroup = $ParentGroup
                }
                return @{ id = "new-$GroupName"; name = $GroupName; fullPathName = "$ParentGroup\$GroupName" }
            }
            Mock Invoke-SepmApi { param($Method, $Uri, $Session, $Body, $ContentType) }

            . $script:SeedScriptPath

            $State = @{ Force = $true }
            $script:result = Invoke-SeedGroups -State $State
        }

        It 'deletes seed groups (not My Company or Default Group)' {
            $script:deleteCalls.Count | Should -Be 126
            # Verify "My Company" and "Default Group" were never passed for deletion
            $deletedGroups = $script:deleteCalls | ForEach-Object { "$($_.ParentGroup)\$($_.GroupName)" }
            $deletedGroups | Should -Not -Contain 'My Company\My Company'
            $deletedGroups | Should -Not -Match 'Default Group'
        }

        It 'deletes deepest leaves before their parents' {
            $deletedPaths = $script:deleteCalls | ForEach-Object { "$($_.ParentGroup)\$($_.GroupName)" }
            $londonIdx = [Array]::IndexOf($deletedPaths, 'My Company\EMEA\UK\London')
            $londonServersIdx = [Array]::IndexOf($deletedPaths, 'My Company\EMEA\UK\London\Servers')
            # Deep leaf should be deleted BEFORE its parent (lower index)
            $londonServersIdx | Should -BeLessThan $londonIdx
        }

        It 'recreates all groups after deletion' {
            $script:createCalls.Count | Should -Be 126
        }

        It 'GroupMap contains newly created IDs' {
            $script:result.GroupMap.Count | Should -Be 126
            $script:result.GroupMap['My Company\EMEA'] | Should -Be 'new-EMEA'
        }
    }
}
