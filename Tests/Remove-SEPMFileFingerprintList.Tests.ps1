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
            $script:fakeSession = Set-TestMocks -Transport {
                return @{ }
            }
        }

        It 'sends DELETE to correct URI using fingerprint list ID' {
            Remove-SEPMFileFingerprintList -FingerprintListID 'FP_TO_DELETE'

            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'DELETE' -and
                $Uri -eq 'https://FakeServer01:1234/sepm/api/v1/policy-objects/fingerprints/FP_TO_DELETE'
            }
        }
    }

    Context 'Delete by Name' {
        BeforeAll {
            $script:fakeSession = Set-TestMocks -Transport {
                return @{ }
            }

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
        }

        It 'resolves name to ID then sends DELETE' {
            Remove-SEPMFileFingerprintList -FingerprintListName 'ListByName'

            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'DELETE' -and
                $Uri -eq 'https://FakeServer01:1234/sepm/api/v1/policy-objects/fingerprints/FP_BY_NAME'
            }
            Should -Invoke Get-SEPMFileFingerprintList -ModuleName PSSymantecSEPM -Exactly 1 -Scope It
        }
    }

    Context 'PassThru behavior' {
        BeforeAll {
            $script:fakeSession = Set-TestMocks -Transport {
                return @{ id = 'DELETED' }
            }
        }

        It 'suppresses output when -PassThru is not specified' {
            $result = Remove-SEPMFileFingerprintList -FingerprintListID 'FP001'

            $result | Should -BeNullOrEmpty
        }

        It 'emits response when -PassThru is specified' {
            $result = Remove-SEPMFileFingerprintList -FingerprintListID 'FP001' -PassThru

            $result | Should -Not -BeNullOrEmpty
            $result.id | Should -Be 'DELETED'
        }
    }

    Context 'Default parameter set' {
        BeforeAll {
            $script:fakeSession = Set-TestMocks -Transport {
                return @{ }
            }
        }

        It 'has Name as the default parameter set' {
            $cmdInfo = Get-Command Remove-SEPMFileFingerprintList
            $cmdInfo.DefaultParameterSet | Should -Be 'Name'
        }
    }

    Context 'Name not found' {
        BeforeAll {
            $script:fakeSession = Set-TestMocks -Transport {
                return @{ }
            }

            Mock Get-SEPMFileFingerprintList -ModuleName PSSymantecSEPM {
                return $null
            }
        }

        It 'attempts DELETE when fingerprint list name does not exist' {
            Remove-SEPMFileFingerprintList -FingerprintListName 'NonExistent'

            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Exactly 1 -Scope It -ParameterFilter {
                $Method -eq 'DELETE' -and
                $Uri -Like '*/fingerprints/*'
            }
        }
    }
}
