[CmdletBinding()]
param()

Describe 'Get-SEPMFirewallPolicy' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment

        InModuleScope PSSymantecSEPM {
            $script:configurationFilePath = Join-Path -Path 'TestDrive:' -ChildPath 'config.json'
            $script:credentialsFilePath   = Join-Path -Path 'TestDrive:' -ChildPath 'creds.xml'
            $script:accessTokenFilePath   = Join-Path -Path 'TestDrive:' -ChildPath 'token.xml'
        }
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context 'All switch' {
        BeforeAll {
            $script:fakeSession = New-TestSession -SkipCert
        }

        It 'returns all FW policies with correct type and count' {
            $apiState = @{ policyCallCount = 0 }
            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $script:fakeSession }
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM -ParameterFilter { $Method -eq 'GET' } {
                if ($Uri -match '/groups') {
                    return @{ content = @(); firstPage = $true; lastPage = $true }
                }
                if ($Uri -match '/policies/summary/fw') {
                    return @{
                        content = @(
                            New-DummyPolicySummary -PolicyName 'FW Policy 1' -PolicyType 'fw'
                            New-DummyPolicySummary -PolicyName 'FW Policy 2' -PolicyType 'fw'
                            New-DummyPolicySummary -PolicyName 'FW Policy 3' -PolicyType 'fw'
                        )
                    }
                }
                if ($Uri -match '/policies/firewall/') {
                    $apiState.policyCallCount++
                    return New-DummyFirewallPolicy -PolicyName "FW Policy $($apiState.policyCallCount)"
                }
                return $null
            }

            $result = Get-SEPMFirewallPolicy -All

            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -Be 3
            $result[0].PSObject.TypeNames[0] | Should -Be 'SEPM.FirewallPolicy'
            $result[1].PSObject.TypeNames[0] | Should -Be 'SEPM.FirewallPolicy'
            $result[2].PSObject.TypeNames[0] | Should -Be 'SEPM.FirewallPolicy'
        }

        It 'honors default DelayMs (200) between API calls' {
            $apiState = @{ policyCallCount = 0 }
            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $script:fakeSession }
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM -ParameterFilter { $Method -eq 'GET' } {
                if ($Uri -match '/groups') {
                    return @{ content = @(); firstPage = $true; lastPage = $true }
                }
                if ($Uri -match '/policies/summary/fw') {
                    return @{
                        content = @(
                            New-DummyPolicySummary -PolicyName 'FW Policy 1' -PolicyType 'fw'
                            New-DummyPolicySummary -PolicyName 'FW Policy 2' -PolicyType 'fw'
                            New-DummyPolicySummary -PolicyName 'FW Policy 3' -PolicyType 'fw'
                        )
                    }
                }
                if ($Uri -match '/policies/firewall/') {
                    $apiState.policyCallCount++
                    return New-DummyFirewallPolicy -PolicyName "FW Policy $($apiState.policyCallCount)"
                }
                return $null
            }
            Mock Start-Sleep -ModuleName PSSymantecSEPM {}

            Get-SEPMFirewallPolicy -All | Out-Null

            Should -Invoke Start-Sleep -ModuleName PSSymantecSEPM -Exactly 2 -Scope It -ParameterFilter { $Milliseconds -eq 200 }
        }

        It 'honors custom DelayMs' {
            $apiState = @{ policyCallCount = 0 }
            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $script:fakeSession }
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM -ParameterFilter { $Method -eq 'GET' } {
                if ($Uri -match '/groups') {
                    return @{ content = @(); firstPage = $true; lastPage = $true }
                }
                if ($Uri -match '/policies/summary/fw') {
                    return @{
                        content = @(
                            New-DummyPolicySummary -PolicyName 'FW Policy 1' -PolicyType 'fw'
                            New-DummyPolicySummary -PolicyName 'FW Policy 2' -PolicyType 'fw'
                            New-DummyPolicySummary -PolicyName 'FW Policy 3' -PolicyType 'fw'
                        )
                    }
                }
                if ($Uri -match '/policies/firewall/') {
                    $apiState.policyCallCount++
                    return New-DummyFirewallPolicy -PolicyName "FW Policy $($apiState.policyCallCount)"
                }
                return $null
            }
            Mock Start-Sleep -ModuleName PSSymantecSEPM {}

            Get-SEPMFirewallPolicy -All -DelayMs 500 | Out-Null

            Should -Invoke Start-Sleep -ModuleName PSSymantecSEPM -Exactly 2 -Scope It -ParameterFilter { $Milliseconds -eq 500 }
        }

        It 'shows Write-Progress with policy name and count' {
            $apiState = @{ policyCallCount = 0 }
            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $script:fakeSession }
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM -ParameterFilter { $Method -eq 'GET' } {
                if ($Uri -match '/groups') {
                    return @{ content = @(); firstPage = $true; lastPage = $true }
                }
                if ($Uri -match '/policies/summary/fw') {
                    return @{
                        content = @(
                            New-DummyPolicySummary -PolicyName 'FW Policy A' -PolicyType 'fw'
                            New-DummyPolicySummary -PolicyName 'FW Policy B' -PolicyType 'fw'
                        )
                    }
                }
                if ($Uri -match '/policies/firewall/') {
                    $apiState.policyCallCount++
                    return New-DummyFirewallPolicy -PolicyName "FW Policy $($apiState.policyCallCount)"
                }
                return $null
            }
            Mock Start-Sleep -ModuleName PSSymantecSEPM {}
            Mock Write-Progress -ModuleName PSSymantecSEPM {}

            Get-SEPMFirewallPolicy -All | Out-Null

            Should -Invoke Write-Progress -ModuleName PSSymantecSEPM -Exactly 2 -Scope It
            Should -Invoke Write-Progress -ModuleName PSSymantecSEPM -Scope It -ParameterFilter {
                $Status -match '1/2 : FW Policy A'
            }
            Should -Invoke Write-Progress -ModuleName PSSymantecSEPM -Scope It -ParameterFilter {
                $Status -match '2/2 : FW Policy B'
            }
        }

        It 'halts on first API error with terminating error and no partial results' {
            $apiState = @{ policyCallCount = 0 }
            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $script:fakeSession }
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM -ParameterFilter { $Method -eq 'GET' } {
                if ($Uri -match '/groups') {
                    return @{ content = @(); firstPage = $true; lastPage = $true }
                }
                if ($Uri -match '/policies/summary/fw') {
                    return @{
                        content = @(
                            New-DummyPolicySummary -PolicyName 'FW Policy 1' -PolicyType 'fw'
                            New-DummyPolicySummary -PolicyName 'FW Policy 2' -PolicyType 'fw'
                            New-DummyPolicySummary -PolicyName 'FW Policy 3' -PolicyType 'fw'
                        )
                    }
                }
                if ($Uri -match '/policies/firewall/') {
                    $apiState.policyCallCount++
                    if ($apiState.policyCallCount -eq 2) {
                        throw 'API error on second policy'
                    }
                    return New-DummyFirewallPolicy -PolicyName "FW Policy $($apiState.policyCallCount)"
                }
                return $null
            }
            Mock Start-Sleep -ModuleName PSSymantecSEPM {}
            Mock Write-Progress -ModuleName PSSymantecSEPM {}

            $errored = $false
            $result = $null
            try {
                $result = Get-SEPMFirewallPolicy -All -ErrorAction Stop
            } catch {
                $errored = $true
            }

            $errored | Should -Be $true
            $result | Should -Be $null
            # Only 2 policy API calls made (1st succeeded, 2nd failed, 3rd never reached)
            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Scope It -ParameterFilter {
                $Uri -match '/policies/firewall/'
            } -Exactly 2
        }
    }
}
