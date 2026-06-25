[CmdletBinding()]
param()

Describe 'Get-SEPMLocation' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context 'Array response (multiple locations)' {
        BeforeAll {
            $null = Set-TestMocks -SkipCert -Transport {
                return @(
                    'Default:api/v1/locations/60B5C584AC17D44C6CC60471B7292FC4',
                    'Office:api/v1/locations/0CCB0536AC1485D1233F341B9495C3C5',
                    'VPN:api/v1/locations/F5E857C9AC1485D13095A0D6E1CD5B25'
                )
            }
            Mock Get-SEPMGroups -ModuleName PSSymantecSEPM {
                return @(
                    [PSCustomObject]@{ id = 'GRP001'; name = 'My Company'; fullPathName = 'My Company' }
                    [PSCustomObject]@{ id = 'GRP002'; name = 'Workstations'; fullPathName = 'My Company\Workstations' }
                )
            }
        }

        It 'returns all locations for a group with parsed properties' {
            $result = Get-SEPMLocation -GroupID 'GRP002'

            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -Be 3
        }

        It 'correctly parses location name and ID from response string' {
            $result = Get-SEPMLocation -GroupID 'GRP002'

            $result[0].locationName | Should -Be 'Default'
            $result[0].locationId | Should -Be '60B5C584AC17D44C6CC60471B7292FC4'
            $result[1].locationName | Should -Be 'Office'
            $result[1].locationId | Should -Be '0CCB0536AC1485D1233F341B9495C3C5'
            $result[2].locationName | Should -Be 'VPN'
            $result[2].locationId | Should -Be 'F5E857C9AC1485D13095A0D6E1CD5B25'
        }

        It 'embeds group information in each location object' {
            $result = Get-SEPMLocation -GroupID 'GRP002'

            $result[0].groupName | Should -Be 'Workstations'
            $result[0].groupId | Should -Be 'GRP002'
            $result[0].groupFullPathName | Should -Be 'My Company\Workstations'
            $result[1].groupName | Should -Be 'Workstations'
            $result[2].groupName | Should -Be 'Workstations'
        }

        It 'calls the correct API endpoint with group ID and hasName query' {
            Get-SEPMLocation -GroupID 'GRP002' | Out-Null

            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Exactly 1 -Scope It -ParameterFilter {
                $Uri -match '/groups/GRP002/locations' -and $Uri -match 'hasName=true'
            }
        }

        It 'returns PSCustomObject type for each location' {
            $result = Get-SEPMLocation -GroupID 'GRP002'

            $result[0] | Should -BeOfType [PSCustomObject]
        }
    }

    Context 'Single string response' {
        BeforeAll {
            $null = Set-TestMocks -SkipCert -Transport {
                return 'Home Office:api/v1/locations/HOMEOFF01'
            }
            Mock Get-SEPMGroups -ModuleName PSSymantecSEPM {
                return @(
                    [PSCustomObject]@{ id = 'GRP003'; name = 'Single Group'; fullPathName = 'My Company\Single' }
                )
            }
        }

        It 'handles a single string response (not wrapped in array)' {
            $result = Get-SEPMLocation -GroupID 'GRP003'

            $result | Should -Not -BeNullOrEmpty
            $result.locationName | Should -Be 'Home Office'
            $result.locationId | Should -Be 'HOMEOFF01'
            $result.groupName | Should -Be 'Single Group'
        }
    }

    Context 'Hashtable (legacy) response' {
        BeforeAll {
            $null = Set-TestMocks -SkipCert -Transport {
                return @{
                    0 = 'Default:api/v1/locations/DEFAULT01'
                    1 = 'SiteA:api/v1/locations/SITEA01'
                }
            }
            Mock Get-SEPMGroups -ModuleName PSSymantecSEPM {
                return @(
                    [PSCustomObject]@{ id = 'GRP004'; name = 'Legacy'; fullPathName = 'My Company\Legacy' }
                )
            }
        }

        It 'handles a hashtable response with numeric keys' {
            $result = Get-SEPMLocation -GroupID 'GRP004'

            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -Be 2
            ($result | Where-Object { $_.locationName -eq 'Default' }).locationId | Should -Be 'DEFAULT01'
            ($result | Where-Object { $_.locationName -eq 'SiteA' }).locationId | Should -Be 'SITEA01'
        }
    }

    Context 'GroupList parameter skips Get-SEPMGroups' {
        BeforeAll {
            $null = Set-TestMocks -SkipCert -Transport {
                return @('Default:api/v1/locations/DEFAULT01')
            }
            Mock Get-SEPMGroups -ModuleName PSSymantecSEPM { throw 'Get-SEPMGroups should not be called' }
        }

        It 'does not call Get-SEPMGroups when GroupList is provided' {
            $groupList = @(
                [PSCustomObject]@{ id = 'GRP001'; name = 'From List'; fullPathName = 'My Company\FromList' }
            )

            $result = Get-SEPMLocation -GroupID 'GRP001' -GroupList $groupList

            $result | Should -Not -BeNullOrEmpty
            $result.groupName | Should -Be 'From List'
            $result.groupId | Should -Be 'GRP001'
            $result.groupFullPathName | Should -Be 'My Company\FromList'

            Should -Invoke Get-SEPMGroups -ModuleName PSSymantecSEPM -Exactly 0 -Scope It
        }
    }

    Context 'Pipeline support' {
        BeforeAll {
            $null = Set-TestMocks -SkipCert -Transport {
                return @('Default:api/v1/locations/DEFAULT01')
            }
            Mock Get-SEPMGroups -ModuleName PSSymantecSEPM {
                return @(
                    [PSCustomObject]@{ id = 'GRP001'; name = 'Group A'; fullPathName = 'My Company\A' }
                    [PSCustomObject]@{ id = 'GRP002'; name = 'Group B'; fullPathName = 'My Company\B' }
                )
            }
        }

        It 'accepts GroupID from the pipeline by value' {
            $result = 'GRP002' | Get-SEPMLocation

            $result | Should -Not -BeNullOrEmpty
            $result.groupId | Should -Be 'GRP002'
            $result.groupName | Should -Be 'Group B'
        }
    }
}
