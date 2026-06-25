[CmdletBinding()]
param()

Describe 'Get-SEPMLocationXML' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context 'Single location XML retrieval' {
        BeforeAll {
            $null = Set-TestMocks -SkipCert -Transport {
                return @{
                    xmlContent = '<Location><Name>Office</Name><Id>LOC001</Id></Location>'
                }
            }
            Mock Get-SEPMGroups -ModuleName PSSymantecSEPM {
                return @(
                    [PSCustomObject]@{ id = 'GRP001'; name = 'My Company'; fullPathName = 'My Company' }
                    [PSCustomObject]@{ id = 'GRP002'; name = 'Workstations'; fullPathName = 'My Company\Workstations' }
                )
            }
        }

        It 'returns XML content for a specific group and location' {
            $result = Get-SEPMLocationXML -GroupID 'GRP001' -LocationID 'LOC001'

            $result | Should -Not -BeNullOrEmpty
        }

        It 'calls the correct API endpoint with group and location IDs' {
            Get-SEPMLocationXML -GroupID 'GRP001' -LocationID 'LOC001' | Out-Null

            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Exactly 1 -Scope It -ParameterFilter {
                $Uri -match '/groups/GRP001/locations/LOC001/xml'
            }
        }

        It 'accepts GroupID from pipeline by property name' {
            $input = [PSCustomObject]@{ GroupID = 'GRP001'; LocationID = 'LOC001' }
            $result = $input | Get-SEPMLocationXML

            $result | Should -Not -BeNullOrEmpty
        }

        It 'passes both GroupID and LocationID when both are in pipeline object' {
            Get-SEPMLocationXML -GroupID 'GRP002' -LocationID 'LOC002' | Out-Null

            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Exactly 1 -Scope It -ParameterFilter {
                $Uri -match '/groups/GRP002/locations/LOC002/xml'
            }
        }
    }
}
