[CmdletBinding()]
param()

Describe 'Get-SEPMPolicyXML' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context 'by PolicyName' {
        BeforeAll {
            $null = Set-TestMocks -Transport { return $null }
            Mock Get-SEPMPoliciesSummary -ModuleName PSSymantecSEPM {
                return @(
                    [PSCustomObject]@{
                        name       = 'Standard Servers - Firewall policy'
                        id         = 'POL-FW-001'
                        policytype = 'fw'
                    }
                )
            }
        }

        It 'returns an XmlDocument with policy XML' {
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                return @{
                    policy_xml = '<FirewallPolicy><Name>Test Policy</Name><Enabled>true</Enabled></FirewallPolicy>'
                }
            }

            $result = Get-SEPMPolicyXML -PolicyName 'Standard Servers - Firewall policy'
            $result | Should -BeOfType [System.Xml.XmlDocument]
            $result.FirewallPolicy.Name | Should -Be 'Test Policy'
            $result.FirewallPolicy.Enabled | Should -Be 'true'
        }

        It 'resolves PolicyName to ID and calls the raw endpoint' {
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                return @{ policy_xml = '<root />' }
            }

            Get-SEPMPolicyXML -PolicyName 'Standard Servers - Firewall policy' | Out-Null
            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'GET' -and $Uri -match '/policies/raw/fw/POL-FW-001$'
            }
        }
    }
}
