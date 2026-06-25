[CmdletBinding()]
param()

Describe 'Add-SEPMFileFingerprintList' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context 'POST method and body shape' {
        BeforeAll {
            $script:fakeSession = Set-TestMocks -Transport {
                return @{ id = 'NEWFP001' }
            }
        }

        It 'sends POST with correct body fields' {
            $result = Add-SEPMFileFingerprintList -name 'NewList' -domainId 'DOM01' -HashType 'SHA256' -description 'Test list' -hashlist @('hash1', 'hash2') -PassThru

            $result.id | Should -Be 'NEWFP001'

            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'POST' -and
                $Uri -eq "$($script:fakeSession.BaseURLv1)/policy-objects/fingerprints" -and
                $ContentType -eq 'application/json' -and
                $Body -match '"name":\s*"NewList"' -and
                $Body -match '"domainId":\s*"DOM01"' -and
                $Body -match '"hashType":\s*"SHA256"' -and
                $Body -match '"description":\s*"Test list"' -and
                $Body -match '"hash1"' -and
                $Body -match '"hash2"'
            }
        }

        It 'sets ContentType to application/json' {
            Add-SEPMFileFingerprintList -name 'JsonTest' -domainId 'DOM02' -HashType 'MD5' -description '' -hashlist @('md5hash') | Out-Null

            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Times 1 -Exactly -ParameterFilter {
                $ContentType -eq 'application/json'
            }
        }
    }

    Context 'Returns API response' {
        BeforeAll {
            $script:fakeSession = Set-TestMocks -Transport {
                return @{ id = 'API123' }
            }
        }

        It 'returns the API response hashtable' {
            $result = Add-SEPMFileFingerprintList -name 'ReturnTest' -domainId 'DOM03' -HashType 'SHA256' -description '' -hashlist @() -PassThru

            $result | Should -Not -BeNullOrEmpty
            $result.id | Should -Be 'API123'
        }
    }

    Context 'PassThru behavior' {
        BeforeAll {
            $script:fakeSession = Set-TestMocks -Transport {
                return @{ id = 'PASSTHRU001' }
            }
        }

        It 'suppresses output when -PassThru is not specified' {
            $result = Add-SEPMFileFingerprintList -name 'Quiet' -domainId 'D01' -HashType 'SHA256' -description '' -hashlist @()

            $result | Should -BeNullOrEmpty
        }

        It 'emits response when -PassThru is specified' {
            $result = Add-SEPMFileFingerprintList -name 'Emit' -domainId 'D02' -HashType 'SHA256' -description '' -hashlist @() -PassThru

            $result | Should -Not -BeNullOrEmpty
            $result.id | Should -Be 'PASSTHRU001'
        }
    }

    Context 'MD5 hash type' {
        BeforeAll {
            $script:fakeSession = Set-TestMocks -Transport {
                return @{ id = 'MD5001' }
            }
        }

        It 'sends MD5 hash type in the body' {
            $result = Add-SEPMFileFingerprintList -name 'MD5List' -domainId 'DOM04' -HashType 'MD5' -description 'MD5 type' -hashlist @('d41d8cd98f00b204e9800998ecf8427e') -PassThru

            $result.id | Should -Be 'MD5001'

            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Times 1 -Exactly -ParameterFilter {
                $Body -match '"hashType":\s*"MD5"' -and
                $Body -match 'd41d8cd98f00b204e9800998ecf8427e'
            }
        }
    }
}
