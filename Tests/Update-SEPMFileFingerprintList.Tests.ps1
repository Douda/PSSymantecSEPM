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
            $fakeSession = New-TestSession
            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }

            $script:apiCalls = @()
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                $script:apiCalls += [PSCustomObject]@{
                    Method      = $Method
                    Uri         = $Uri
                    Body        = $Body
                    ContentType = $ContentType
                }
                return @{ id = 'FP-ID-123'; name = 'MyFingerprints' }
            }
        }

        It 'sends POST with fingerprint body to the correct URI' {
            $hashes = @('abc123', 'def456')
            Update-SEPMFileFingerprintList -FingerprintListID 'FP-ID-123' `
                -name 'Updated List' -domainId 'dom-1' -HashType 'SHA256' `
                -description 'Updated fingerprints' -hashlist $hashes

            $script:apiCalls.Count | Should -Be 1
            $script:apiCalls[0].Method      | Should -Be 'POST'
            $script:apiCalls[0].Uri         | Should -Be "$($fakeSession.BaseURLv1)/policy-objects/fingerprints/FP-ID-123"
            $script:apiCalls[0].ContentType | Should -Be 'application/json'

            $body = $script:apiCalls[0].Body | ConvertFrom-Json
            $body.name        | Should -Be 'Updated List'
            $body.domainId    | Should -Be 'dom-1'
            $body.hashType    | Should -Be 'SHA256'
            $body.description | Should -Be 'Updated fingerprints'
            $body.data[0]     | Should -Be 'abc123'
            $body.data[1]     | Should -Be 'def456'
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
            $fakeSession = New-TestSession
            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }

            # Mock Get-SEPMFileFingerprintList to resolve name → ID
            Mock Get-SEPMFileFingerprintList -ModuleName PSSymantecSEPM {
                return [PSCustomObject]@{ id = 'FP-RESOLVED-789'; name = 'ExistingFingerprints' }
            }

            $script:apiCalls = @()
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                $script:apiCalls += [PSCustomObject]@{
                    Method = $Method
                    Uri    = $Uri
                    Body   = $Body
                }
                return @{ id = 'FP-RESOLVED-789'; name = 'Updated' }
            }
        }

        It 'resolves FingerprintListName to ID and uses it in URI' {
            Update-SEPMFileFingerprintList -FingerprintListName 'ExistingFingerprints' `
                -name 'Renamed' -domainId 'dd' -HashType 'SHA256' -hashlist @('hash1')

            $script:apiCalls.Count | Should -Be 1
            $script:apiCalls[0].Method | Should -Be 'POST'
            $script:apiCalls[0].Uri    | Should -Be "$($fakeSession.BaseURLv1)/policy-objects/fingerprints/FP-RESOLVED-789"
        }
    }

    Context 'body construction' {
        BeforeAll {
            $fakeSession = New-TestSession
            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }

            $script:apiCalls = @()
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                $script:apiCalls += [PSCustomObject]@{
                    Method = $Method
                    Uri    = $Uri
                    Body   = $Body
                }
                return @{}
            }
        }

        It 'sends array of hashes in data field' {
            $hashes = 1..5 | ForEach-Object { "hash-$_" }
            Update-SEPMFileFingerprintList -FingerprintListID 'FP-HASHES' `
                -name 'HashTest' -domainId 'd' -HashType 'MD5' -hashlist $hashes

            $body = $script:apiCalls[0].Body | ConvertFrom-Json
            $body.data.Count | Should -Be 5
            $body.data[0]    | Should -Be 'hash-1'
            $body.data[4]    | Should -Be 'hash-5'
        }

        It 'handles null/empty description' {
            Update-SEPMFileFingerprintList -FingerprintListID 'FP-NODESC' `
                -name 'NoDesc' -domainId 'd' -HashType 'SHA256' -hashlist @('h1')

            $body = $script:apiCalls[1].Body | ConvertFrom-Json
            $body.description | Should -BeNullOrEmpty
            $body.name        | Should -Be 'NoDesc'
        }

        It 'handles single hash string' {
            Update-SEPMFileFingerprintList -FingerprintListID 'FP-SINGLE' `
                -name 'SingleHash' -domainId 'd' -HashType 'SHA256' -hashlist 'single-hash'

            $body = $script:apiCalls[2].Body | ConvertFrom-Json
            $body.data | Should -Be 'single-hash'
        }
    }
}
