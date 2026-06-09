[CmdletBinding()]
param()

Describe 'Get-SEPMLicense' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context 'full license (default)' {
        BeforeAll {
            $fakeSession = New-TestSession
            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }
        }

        It 'returns license info with expected keys' {
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                return @{
                    serialNumber       = 'M3689526915'
                    licenseType        = 0
                    seats              = 0
                    startDate          = 1780815600000
                    expireDate         = 1786085999000
                    endDate            = 1786085999000
                    associatedLicenses = ''
                    productName        = ''
                    keyNames           = @('scs_content')
                }
            }

            $result = Get-SEPMLicense
            $result.serialNumber | Should -Be 'M3689526915'
            $result.licenseType  | Should -Be 0
            $result.keyNames     | Should -Not -BeNullOrEmpty
        }

        It 'calls the /licenses endpoint' {
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM { return @{ ok = $true } }

            Get-SEPMLicense | Out-Null
            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'GET' -and $Uri -match '/licenses$'
            }
        }
    }

    Context 'license summary' {
        BeforeAll {
            $fakeSession = New-TestSession
            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }
        }

        It 'returns summary with different keys when -Summary is used' {
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                return @{
                    license_type            = 'TRIAL'
                    ended                   = $false
                    service_end_date        = '1786085999000'
                    service_expiration_date = '1786085999000'
                    serial_number           = 'M3689526915'
                    ordered_quantity        = 0
                    unexpired_seats         = 0
                }
            }

            $result = Get-SEPMLicense -Summary
            $result.license_type  | Should -Be 'TRIAL'
            $result.serial_number | Should -Be 'M3689526915'
            $result.ended         | Should -BeFalse
        }

        It 'calls the /licenses/summary endpoint with -Summary' {
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM { return @{ ok = $true } }

            Get-SEPMLicense -Summary | Out-Null
            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'GET' -and $Uri -match '/licenses/summary$'
            }
        }
    }
}
