[CmdletBinding()]
param()

Describe 'Get-SEPMPoliciesSummary' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context 'all policies (default)' {
        BeforeAll {
            $fakeSession = New-TestSession
            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }
            Mock Get-SEPMGroups -ModuleName PSSymantecSEPM {
                return @(
                    [PSCustomObject]@{ id = 'ABCD'; fullPathName = 'My Company\Workstations' }
                    [PSCustomObject]@{ id = 'EFGH'; fullPathName = 'My Company\Servers' }
                )
            }
        }

        It 'returns policy summaries with expected fields' {
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                return @{
                    content = @(
                        @{
                            name             = 'Intensive Protection policy'
                            policytype       = 'hid'
                            enabled          = $false
                            domainid         = '1E814550AC1E00027245A393F26DBE37'
                            id               = 'POL001'
                            desc             = 'Test policy'
                            lastmodifiedtime = 1720096619241
                            assignedtolocations = @(
                                @{
                                    groupId         = 'ABCD'
                                    defaultLocationId = 'LOC001'
                                    locationIds     = @('LOC001')
                                }
                            )
                        }
                    )
                }
            }

            $result = Get-SEPMPoliciesSummary
            $result.Count        | Should -Be 1
            $result[0].name      | Should -Be 'Intensive Protection policy'
            $result[0].policytype | Should -Be 'hid'
            $result[0].enabled   | Should -BeFalse
        }

        It 'adds groupNameFullPath to assigned locations' {
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                return @{
                    content = @(
                        @{
                            name               = 'Test'
                            policytype         = 'av'
                            enabled            = $true
                            domainid           = 'D001'
                            id                 = 'P001'
                            assignedtolocations = @(
                                @{
                                    groupId         = 'ABCD'
                                    defaultLocationId = 'L001'
                                    locationIds     = @('L001')
                                }
                            )
                        }
                    )
                }
            }

            $result = Get-SEPMPoliciesSummary
            $result[0].assignedtolocations[0].groupNameFullPath | Should -Be 'My Company\Workstations'
        }

        It 'adds SEPM.PolicySummary type name' {
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                return @{
                    content = @(
                        @{
                            name       = 'TypeTest'
                            policytype = 'fw'
                            enabled    = $true
                            domainid   = 'D001'
                            id         = 'P002'
                            assignedtolocations = @()
                        }
                    )
                }
            }

            $result = Get-SEPMPoliciesSummary
            $result[0].PSObject.TypeNames[0] | Should -Be 'SEPM.PolicySummary'
        }

        It 'calls the correct API endpoint for all policies' {
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM { return @{ content = @() } }

            Get-SEPMPoliciesSummary | Out-Null
            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'GET' -and $Uri -match '/policies/summary$'
            }
        }
    }

    Context 'filtered by policy type' {
        BeforeAll {
            $fakeSession = New-TestSession
            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }
            Mock Get-SEPMGroups -ModuleName PSSymantecSEPM { return @() }
        }

        It 'calls the type-specific endpoint when PolicyType is specified' {
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM { return @{ content = @() } }

            Get-SEPMPoliciesSummary -PolicyType fw | Out-Null
            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'GET' -and $Uri -match '/policies/summary/fw$'
            }
        }
    }
}
