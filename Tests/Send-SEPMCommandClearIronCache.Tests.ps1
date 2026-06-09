[CmdletBinding()]
param()

Describe 'Send-SEPMCommandClearIronCache' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context 'ComputerName with SHA256' {
        BeforeAll {
            $script:dummyComputer = [PSCustomObject]@{
                uniqueId     = '12345'
                computerName = 'TEST-PC'
            }

            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM {
                return New-TestSession
            }
            Mock Get-SEPComputers -ModuleName PSSymantecSEPM {
                return $script:dummyComputer
            }
        }

        It 'POSTs to the ironcache endpoint with SHA256 hash' {
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                return @{ status = 'success' }
            }

            $sha256Hash = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'
            $result = Send-SEPMCommandClearIronCache -ComputerName 'TEST-PC' -SHA256 $sha256Hash
            $result['status'] | Should -Be 'success'

            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Exactly 1 -Scope It -ParameterFilter {
                $Method -eq 'POST' -and
                $Uri -match '/command-queue/ironcache' -and
                $ContentType -eq 'application/json'
            }
        }

        It 'sends JSON body with hashType and data array' {
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                return @{ status = 'success' }
            }

            $sha256Hash = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'
            Send-SEPMCommandClearIronCache -ComputerName 'TEST-PC' -SHA256 $sha256Hash | Out-Null

            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Exactly 1 -Scope It -ParameterFilter {
                $body = $Body | ConvertFrom-Json
                $body.hashType -eq 'sha256' -and
                $body.data.Count -eq 1 -and
                $body.data[0] -eq 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'
            }
        }

        It 'includes computer_ids query param in the URI' {
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                return @{ status = 'success' }
            }

            $sha256Hash = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'
            Send-SEPMCommandClearIronCache -ComputerName 'TEST-PC' -SHA256 $sha256Hash | Out-Null

            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Exactly 1 -Scope It -ParameterFilter {
                $Uri -match 'computer_ids=12345'
            }
        }
    }

    Context 'ComputerName with MD5' {
        BeforeAll {
            $script:dummyComputer = [PSCustomObject]@{
                uniqueId     = '12345'
                computerName = 'TEST-PC'
            }

            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM {
                return New-TestSession
            }
            Mock Get-SEPComputers -ModuleName PSSymantecSEPM {
                return $script:dummyComputer
            }
        }

        It 'sends MD5 hash type in the body' {
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                return @{ status = 'success' }
            }

            $md5Hash = 'd41d8cd98f00b204e9800998ecf8427e'
            Send-SEPMCommandClearIronCache -ComputerName 'TEST-PC' -MD5 $md5Hash | Out-Null

            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Exactly 1 -Scope It -ParameterFilter {
                $body = $Body | ConvertFrom-Json
                $body.hashType -eq 'md5' -and
                $body.data[0] -eq 'd41d8cd98f00b204e9800998ecf8427e'
            }
        }
    }

    Context 'GroupName' {
        BeforeAll {
            $script:dummyGroup = [PSCustomObject]@{
                id           = 'group-001'
                fullPathName = 'My Company\TestGroup'
            }

            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM {
                return New-TestSession
            }
            Mock Get-SEPMGroups -ModuleName PSSymantecSEPM {
                return $script:dummyGroup
            }
        }

        It 'POSTs to the ironcache endpoint for a given group' {
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                return @{ status = 'success' }
            }

            $result = Send-SEPMCommandClearIronCache -GroupName 'My Company\TestGroup'
            $result['status'] | Should -Be 'success'

            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Exactly 1 -Scope It -ParameterFilter {
                $Method -eq 'POST' -and
                $Uri -match '/command-queue/ironcache' -and
                $Uri -match 'group_ids=group-001'
            }
        }
    }

    Context 'Error handling' {
        BeforeAll {
            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM {
                return New-TestSession
            }
        }

        It 'propagates API error for non-existent computer' {
            Mock Get-SEPComputers -ModuleName PSSymantecSEPM { return @() }
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM { return @{ error = 'Computer not found' } }

            $sha256Hash = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'
            $result = Send-SEPMCommandClearIronCache -ComputerName 'NONEXISTENT' -SHA256 $sha256Hash
            $result['error'] | Should -Be 'Computer not found'

            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Exactly 1 -Scope It
        }
    }
}
