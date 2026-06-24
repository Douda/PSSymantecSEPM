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
            $script:fakeSession = New-TestSession

            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $script:fakeSession }

            $script:capturedBody = $null
            $script:capturedContentType = $null
            $script:capturedMethod = $null
            $script:capturedUri = $null

            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                $script:capturedBody = $Body
                $script:capturedContentType = $ContentType
                $script:capturedMethod = $Method
                $script:capturedUri = $Uri
                return @{ id = 'NEWFP001' }
            }
        }

        It 'sends POST with correct body fields' {
            $result = Add-SEPMFileFingerprintList -name 'NewList' -domainId 'DOM01' -HashType 'SHA256' -description 'Test list' -hashlist @('hash1', 'hash2') -PassThru

            $result.id | Should -Be 'NEWFP001'
            $script:capturedMethod | Should -Be 'POST'
            $script:capturedUri    | Should -Be 'https://FakeServer01:1234/sepm/api/v1/policy-objects/fingerprints'

            $body = $script:capturedBody | ConvertFrom-Json
            $body.name        | Should -Be 'NewList'
            $body.domainId    | Should -Be 'DOM01'
            $body.hashType    | Should -Be 'SHA256'
            $body.description | Should -Be 'Test list'
            @($body.data).Count | Should -Be 2
            $body.data[0] | Should -Be 'hash1'
            $body.data[1] | Should -Be 'hash2'
        }

        It 'sets ContentType to application/json' {
            Add-SEPMFileFingerprintList -name 'JsonTest' -domainId 'DOM02' -HashType 'MD5' -description '' -hashlist @('md5hash') | Out-Null

            $script:capturedContentType | Should -Be 'application/json'
        }
    }

    Context 'Returns API response' {
        BeforeAll {
            $script:fakeSession = New-TestSession

            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $script:fakeSession }
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
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
            $script:fakeSession = New-TestSession

            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $script:fakeSession }
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
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
            $script:fakeSession = New-TestSession

            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $script:fakeSession }

            $script:capturedBodyMD5 = $null

            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                $script:capturedBodyMD5 = $Body
                return @{ id = 'MD5001' }
            }
        }

        It 'sends MD5 hash type in the body' {
            $result = Add-SEPMFileFingerprintList -name 'MD5List' -domainId 'DOM04' -HashType 'MD5' -description 'MD5 type' -hashlist @('d41d8cd98f00b204e9800998ecf8427e') -PassThru

            $result.id | Should -Be 'MD5001'
            $body = $script:capturedBodyMD5 | ConvertFrom-Json
            $body.hashType | Should -Be 'MD5'
            @($body.data).Count | Should -Be 1
        }
    }
}
