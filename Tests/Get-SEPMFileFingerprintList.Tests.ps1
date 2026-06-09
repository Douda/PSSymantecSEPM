[CmdletBinding()]
param()

Describe 'Get-SEPMFileFingerprintList' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context 'Name lookup' {
        BeforeAll {
            $script:fakeSession = New-TestSession

            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $script:fakeSession }
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                return @{
                    source      = 'WEBSERVICE'
                    id          = 'FP001'
                    hashType    = 'SHA256'
                    description = 'Test fingerprint list'
                    data        = @('abc123', 'def456')
                    groupIds    = @('grp1', 'grp2')
                    name        = 'TestFingerprintList'
                }
            }
        }

        It 'returns fingerprint list when looked up by name' {
            $result = Get-SEPMFileFingerprintList -FingerprintListName 'TestFingerprintList'

            $result | Should -Not -BeNullOrEmpty
            $result.name | Should -Be 'TestFingerprintList'
            $result.id   | Should -Be 'FP001'
            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Exactly 1 -Scope It
            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -ParameterFilter {
                $Method -eq 'GET' -and $Uri -match '/policy-objects/fingerprints\?'
            } -Exactly 1 -Scope It
        }
    }

    Context 'ID lookup' {
        BeforeAll {
            $script:fakeSession = New-TestSession

            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $script:fakeSession }
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                return @{
                    source      = 'WEBSERVICE'
                    id          = 'FP002'
                    hashType    = 'MD5'
                    description = 'MD5 fingerprint list'
                    data        = @('hash1', 'hash2', 'hash3')
                    groupIds    = @()
                    name        = 'MD5List'
                }
            }
        }

        It 'returns fingerprint list when looked up by ID' {
            $result = Get-SEPMFileFingerprintList -FingerprintListID 'FP002'

            $result | Should -Not -BeNullOrEmpty
            $result.name | Should -Be 'MD5List'
            $result.id   | Should -Be 'FP002'
            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Exactly 1 -Scope It
            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -ParameterFilter {
                $Method -eq 'GET' -and $Uri -eq 'https://FakeServer01:1234/sepm/api/v1/policy-objects/fingerprints/FP002'
            } -Exactly 1 -Scope It
        }
    }

    Context 'Field structure' {
        BeforeAll {
            $script:fakeSession = New-TestSession

            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $script:fakeSession }
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                return @{
                    source      = 'WEBSERVICE'
                    id          = 'FP003'
                    hashType    = 'SHA256'
                    description = 'Field test'
                    data        = @('hashA', 'hashB')
                    groupIds    = @('grpA')
                    name        = 'FieldTest'
                }
            }
        }

        It 'returns all required fields on a fingerprint list' {
            $result = Get-SEPMFileFingerprintList -FingerprintListName 'FieldTest'

            $result.id          | Should -Not -BeNullOrEmpty
            $result.name        | Should -Not -BeNullOrEmpty
            $result.hashType    | Should -Not -BeNullOrEmpty
            $result.data        | Should -Not -BeNullOrEmpty
            $result.groupIds    | Should -Not -BeNullOrEmpty
            $result.source      | Should -Not -BeNullOrEmpty
            $result.description | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Name not found' {
        BeforeAll {
            $script:fakeSession = New-TestSession

            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $script:fakeSession }
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                return 'Error: fingerprint list not found'
            }
        }

        It 'returns error string when fingerprint list name does not exist' {
            $result = Get-SEPMFileFingerprintList -FingerprintListName 'NonExistent'

            $result | Should -BeOfType ([string])
            $result | Should -Match 'Error: fingerprint list not found'
        }
    }
}
