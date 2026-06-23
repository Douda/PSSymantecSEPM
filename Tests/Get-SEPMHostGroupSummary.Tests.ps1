[CmdletBinding()]
param()

Describe 'Get-SEPMHostGroupSummary' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context 'Single page' {
        It 'returns host group summaries from a single API page' {
            $fakeSession = New-TestSession -SkipCert

            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                return @{
                    content   = @(
                        @{ id = 'hg1'; name = 'Host Group A'; domainid = 'dom1'; lastmodifiedtime = 1693832218775 }
                        @{ id = 'hg2'; name = 'Host Group B'; domainid = 'dom1'; lastmodifiedtime = 1693832218776 }
                    )
                    firstPage = $true
                    lastPage  = $true
                }
            }

            $result = Get-SEPMHostGroupSummary
            $result | Should -Not -BeNullOrEmpty
            @($result).Count | Should -Be 2
            $result[0].name | Should -Be 'Host Group A'
            $result[1].name | Should -Be 'Host Group B'
        }
    }

    Context 'Pagination' {
        It 'paginates through multiple pages' {
            $fakeSession = New-TestSession -SkipCert

            $state = @{ callCount = 0 }
            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                $state.callCount++
                if ($state.callCount -ge 2) {
                    return @{
                        content   = @(
                            @{ id = 'hg51'; name = 'Host Group 51'; domainid = 'dom1'; lastmodifiedtime = 1693832218800 }
                        )
                        firstPage = $false; lastPage = $true
                    }
                } else {
                    $page1 = 1..50 | ForEach-Object {
                        @{ id = "hg$_"; name = "Host Group $_"; domainid = 'dom1'; lastmodifiedtime = 1693832218000 }
                    }
                    return @{ content = $page1; firstPage = $true; lastPage = $false }
                }
            }

            $result = Get-SEPMHostGroupSummary
            $result | Should -Not -BeNullOrEmpty
            @($result).Count | Should -Be 51
            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Exactly 2 -Scope It
        }
    }

    Context 'DomainId parameter' {
        It 'passes domainId as a query parameter' {
            $fakeSession = New-TestSession -SkipCert

            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                return @{
                    content   = @(
                        @{ id = 'hg1'; name = 'Host Group A'; domainid = 'abc123'; lastmodifiedtime = 1693832218775 }
                    )
                    firstPage = $true
                    lastPage  = $true
                }
            }

            $result = Get-SEPMHostGroupSummary -DomainId 'abc123'
            @($result).Count | Should -Be 1
            $result[0].domainid | Should -Be 'abc123'
            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Exactly 1 -Scope It
            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -ParameterFilter {
                $Method -eq 'GET' -and $Uri -match 'domainId=abc123'
            } -Exactly 1 -Scope It
        }
    }
}
