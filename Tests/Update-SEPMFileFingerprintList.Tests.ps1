[CmdletBinding()]
param()

Describe 'Update-SEPMFileFingerprintList' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context 'by FingerprintListID' {
        BeforeAll {
            $script:fakeSession = Set-TestMocks -Transport {
                return @{ id = 'FP-ID-123'; name = 'MyFingerprints' }
            }
        }

        It 'sends POST with fingerprint body to the correct URI' {
            $hashes = @('abc123', 'def456')
            Update-SEPMFileFingerprintList -FingerprintListID 'FP-ID-123' `
                -name 'Updated List' -domainId 'dom-1' -HashType 'SHA256' `
                -description 'Updated fingerprints' -hashlist $hashes

            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'POST' -and
                $Uri -eq "$($script:fakeSession.BaseURLv1)/policy-objects/fingerprints/FP-ID-123" -and
                $ContentType -eq 'application/json' -and
                $Body -match '"name":\s*"Updated List"' -and
                $Body -match '"domainId":\s*"dom-1"' -and
                $Body -match '"hashType":\s*"SHA256"' -and
                $Body -match '"description":\s*"Updated fingerprints"' -and
                $Body -match '"abc123"' -and
                $Body -match '"def456"'
            }
        }

        It 'returns the Invoke-SepmApi response' {
            $result = Update-SEPMFileFingerprintList -FingerprintListID 'FP-ID-456' `
                -name 'Test' -domainId 'd1' -HashType 'MD5' -hashlist @('aaa', 'bbb') -PassThru

            $result.id   | Should -Be 'FP-ID-123'
            $result.name | Should -Be 'MyFingerprints'
        }

        It 'suppresses output when -PassThru is not specified' {
            $result = Update-SEPMFileFingerprintList -FingerprintListID 'FP-ID-456' `
                -name 'Test' -domainId 'd1' -HashType 'MD5' -hashlist @('aaa')

            $result | Should -BeNullOrEmpty
        }
    }

    Context 'by FingerprintListName' {
        BeforeAll {
            $script:fakeSession = Set-TestMocks -Transport {
                return @{ id = 'FP-RESOLVED-789'; name = 'Updated' }
            }

            # Mock Get-SEPMFileFingerprintList to resolve name → ID
            Mock Get-SEPMFileFingerprintList -ModuleName PSSymantecSEPM {
                return [PSCustomObject]@{ id = 'FP-RESOLVED-789'; name = 'ExistingFingerprints' }
            }
        }

        It 'resolves FingerprintListName to ID and uses it in URI' {
            Update-SEPMFileFingerprintList -FingerprintListName 'ExistingFingerprints' `
                -name 'Renamed' -domainId 'dd' -HashType 'SHA256' -hashlist @('hash1')

            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'POST' -and
                $Uri -eq "$($script:fakeSession.BaseURLv1)/policy-objects/fingerprints/FP-RESOLVED-789"
            }
        }
    }

    Context 'body construction' {
        BeforeAll {
            $script:fakeSession = Set-TestMocks -Transport {
                return @{}
            }
        }

        It 'sends array of hashes in data field' {
            $hashes = 1..5 | ForEach-Object { "hash-$_" }
            Update-SEPMFileFingerprintList -FingerprintListID 'FP-HASHES' `
                -name 'HashTest' -domainId 'd' -HashType 'MD5' -hashlist $hashes

            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Times 1 -Exactly -ParameterFilter {
                $Body -match '"hash-1"' -and
                $Body -match '"hash-5"'
            }
        }

        It 'handles null/empty description' {
            Update-SEPMFileFingerprintList -FingerprintListID 'FP-NODESC' `
                -name 'NoDesc' -domainId 'd' -HashType 'SHA256' -hashlist @('h1')

            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Times 1 -Exactly -ParameterFilter {
                $Body -match '"name":\s*"NoDesc"' -and
                $Body -notmatch '"description"'
            }
        }

        It 'handles single hash string' {
            Update-SEPMFileFingerprintList -FingerprintListID 'FP-SINGLE' `
                -name 'SingleHash' -domainId 'd' -HashType 'SHA256' -hashlist 'single-hash'

            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Times 1 -Exactly -ParameterFilter {
                $Body -match '"single-hash"'
            }
        }
    }
}
