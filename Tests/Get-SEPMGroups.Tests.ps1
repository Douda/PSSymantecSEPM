[CmdletBinding()]
param()

Describe 'Get-SEPMGroups' {
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

    Context 'Single page' {
        It 'returns groups from a single API page' {
            $fakeSession = New-TestSession -SkipCert

            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                return @{
                    content   = @(
                        @{ id = 'grp1'; name = 'My Company'; fullPathName = 'My Company' }
                        @{ id = 'grp2'; name = 'Workstations'; fullPathName = 'My Company\Workstations' }
                    )
                    firstPage = $true
                    lastPage  = $true
                }
            }

            $result = Get-SEPMGroups
            $result | Should -Not -BeNullOrEmpty
            @($result).Count | Should -Be 2
            $result[0].name | Should -Be 'My Company'
            $result[1].name | Should -Be 'Workstations'
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
                            @{ id = 'grp26'; name = 'Group26'; fullPathName = 'My Company\Group26' }
                        )
                        firstPage = $false; lastPage = $true
                    }
                } else {
                    $page1 = 1..25 | ForEach-Object { @{ id = "grp$_"; name = "Group$_"; fullPathName = "My Company\Group$_" } }
                    return @{ content = $page1; firstPage = $true; lastPage = $false }
                }
            }

            $result = Get-SEPMGroups
            $result | Should -Not -BeNullOrEmpty
            @($result).Count | Should -Be 26
            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Exactly 2 -Scope It
        }
    }
}
