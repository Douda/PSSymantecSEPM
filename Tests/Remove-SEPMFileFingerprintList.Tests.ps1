[CmdletBinding()]
param()

Describe 'Remove-SEPMFileFingerprintList' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context 'Delete by ID' {
        BeforeAll {
            $script:fakeSession = New-TestSession

            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $script:fakeSession }

            $script:capturedMethod = $null
            $script:capturedUri = $null

            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                $script:capturedMethod = $Method
                $script:capturedUri = $Uri
                return @{ }
            }
        }

        It 'sends DELETE to correct URI using fingerprint list ID' {
            $result = Remove-SEPMFileFingerprintList -FingerprintListID 'FP_TO_DELETE'

            $script:capturedMethod | Should -Be 'DELETE'
            $script:capturedUri    | Should -Be 'https://FakeServer01:1234/sepm/api/v1/policy-objects/fingerprints/FP_TO_DELETE'
        }
    }

    Context 'Delete by Name' {
        BeforeAll {
            $script:fakeSession = New-TestSession

            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $script:fakeSession }

            Mock Get-SEPMFileFingerprintList -ModuleName PSSymantecSEPM {
                return @{
                    source      = 'WEBSERVICE'
                    id          = 'FP_BY_NAME'
                    hashType    = 'SHA256'
                    description = ''
                    data        = @()
                    groupIds    = @()
                    name        = 'ListByName'
                }
            }

            $script:capturedMethod = $null
            $script:capturedUri = $null

            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                $script:capturedMethod = $Method
                $script:capturedUri = $Uri
                return @{ }
            }
        }

        It 'resolves name to ID then sends DELETE' {
            $result = Remove-SEPMFileFingerprintList -FingerprintListName 'ListByName'

            $script:capturedMethod | Should -Be 'DELETE'
            $script:capturedUri    | Should -Be 'https://FakeServer01:1234/sepm/api/v1/policy-objects/fingerprints/FP_BY_NAME'
            Should -Invoke Get-SEPMFileFingerprintList -ModuleName PSSymantecSEPM -Exactly 1 -Scope It
        }
    }

    Context 'Default parameter set' {
        BeforeAll {
            $fakeSession = New-TestSession
            Mock Initialize-SEPMSession { return $fakeSession }
        }

        It 'has Name as the default parameter set' {
            $cmdInfo = Get-Command Remove-SEPMFileFingerprintList
            $cmdInfo.DefaultParameterSet | Should -Be 'Name'
        }
    }

    Context 'Name not found' {
        BeforeAll {
            $script:fakeSession = New-TestSession

            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $script:fakeSession }

            Mock Get-SEPMFileFingerprintList -ModuleName PSSymantecSEPM {
                return $null
            }

            $script:capturedUri = $null

            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                $script:capturedUri = $Uri
                return @{ }
            }
        }

        It 'attempts DELETE when fingerprint list name does not exist' {
            $result = Remove-SEPMFileFingerprintList -FingerprintListName 'NonExistent'

            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Exactly 1 -Scope It
            $script:capturedUri | Should -BeLike '*/fingerprints/*'
        }
    }
}
