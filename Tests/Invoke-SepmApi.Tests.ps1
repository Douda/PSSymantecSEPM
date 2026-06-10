[CmdletBinding()]
param()

Describe 'Invoke-SepmApi' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context 'Session parameter set' {
        It 'extracts Headers and SkipCert from the session object and returns [hashtable]' {
            $session = New-TestSession -ServerAddress 'SEPM01' -Port '8446' -Token 'TestToken123' -SkipCert

            InModuleScope PSSymantecSEPM -Parameters @{ session = $session } {
                $PSVersionTable = @{ PSVersion = [version]'7.0.0' }

                Mock Invoke-RestMethod {
                    return '{"API_SEQUENCE":"240604011","API_VERSION":"14.3.9000","version":"14.3.25029.9000"}'
                }

                $result = Invoke-SepmApi -Method GET -Uri 'https://SEPM01:8446/sepm/api/v1/version' -Session $session

                $result | Should -Not -BeNullOrEmpty
                $result -is [hashtable] | Should -Be $true
                $result.API_SEQUENCE | Should -Be '240604011'
                $result.API_VERSION  | Should -Be '14.3.9000'
                $result.version      | Should -Be '14.3.25029.9000'
            }
        }

        It 'passes Authorization header from session to Invoke-RestMethod' {
            $session = New-TestSession -ServerAddress 'SEPM01' -Port '8446' -Token 'AuthHeaderToken'

            InModuleScope PSSymantecSEPM -Parameters @{ session = $session } {
                $PSVersionTable = @{ PSVersion = [version]'7.0.0' }

                Mock Invoke-RestMethod { return '{"ok":true}' }

                Invoke-SepmApi -Method GET -Uri 'https://SEPM01:8446/sepm/api/v1/test' -Session $session | Out-Null

                Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
                    $Headers.Authorization -eq 'Bearer AuthHeaderToken'
                }
            }
        }

        It 'throws when Session is missing Headers property' {
            $badSession = [PSCustomObject]@{ SkipCert = $false }

            InModuleScope PSSymantecSEPM -Parameters @{ badSession = $badSession } {
                $PSVersionTable = @{ PSVersion = [version]'7.0.0' }

                { Invoke-SepmApi -Method GET -Uri 'https://example.com' -Session $badSession } |
                    Should -Throw -ExpectedMessage '*Headers*'
            }
        }

        It 'throws when Session is missing SkipCert property' {
            $badSession = [PSCustomObject]@{ Headers = @{ Authorization = 'Bearer x' } }

            InModuleScope PSSymantecSEPM -Parameters @{ badSession = $badSession } {
                $PSVersionTable = @{ PSVersion = [version]'7.0.0' }

                { Invoke-SepmApi -Method GET -Uri 'https://example.com' -Session $badSession } |
                    Should -Throw -ExpectedMessage '*SkipCert*'
            }
        }
    }

    Context 'Manual parameter set' {
        It 'uses Headers and SkipCert from parameters' {
            InModuleScope PSSymantecSEPM {
                $PSVersionTable = @{ PSVersion = [version]'7.0.0' }

                Mock Invoke-RestMethod { return '{"manual":"ok"}' }

                $result = Invoke-SepmApi -Method GET -Uri 'https://example.com/api' `
                    -Headers @{ Authorization = 'Bearer ManualToken'; 'X-Custom' = 'value' } `
                    -SkipCert $true

                $result -is [hashtable] | Should -Be $true
                $result.manual | Should -Be 'ok'
            }
        }

        It 'passes custom headers to Invoke-RestMethod' {
            InModuleScope PSSymantecSEPM {
                $PSVersionTable = @{ PSVersion = [version]'7.0.0' }

                Mock Invoke-RestMethod { return '{}' }

                Invoke-SepmApi -Method GET -Uri 'https://example.com/api' `
                    -Headers @{ Authorization = 'Bearer M'; 'X-Custom' = 'customVal' } `
                    -SkipCert $false | Out-Null

                Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
                    $Headers.'X-Custom' -eq 'customVal' -and
                    $Headers.Authorization -eq 'Bearer M'
                }
            }
        }

        It 'calls Invoke-RestMethod without -SkipCertificateCheck when SkipCert is $false' {
            InModuleScope PSSymantecSEPM {
                $PSVersionTable = @{ PSVersion = [version]'7.0.0' }

                Mock Invoke-RestMethod { return '{}' } -ParameterFilter { $SkipCertificateCheck -eq $false -or -not $PSBoundParameters.ContainsKey('SkipCertificateCheck') }

                Invoke-SepmApi -Method GET -Uri 'https://example.com/api' `
                    -Headers @{ Authorization = 'Bearer x' } `
                    -SkipCert $false | Out-Null

                Should -Invoke Invoke-RestMethod -Times 1 -Exactly
            }
        }

        It 'calls Invoke-RestMethod with -SkipCertificateCheck when SkipCert is $true' {
            InModuleScope PSSymantecSEPM {
                $PSVersionTable = @{ PSVersion = [version]'7.0.0' }

                Mock Invoke-RestMethod { return '{}' }

                Invoke-SepmApi -Method GET -Uri 'https://example.com/api' `
                    -Headers @{ Authorization = 'Bearer x' } `
                    -SkipCert $true | Out-Null

                Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter { $SkipCertificateCheck -eq $true }
            }
        }
    }

    Context 'HTTP method and body passthrough' {
        It 'passes Method, Body, and ContentType to Invoke-RestMethod' {
            $session = New-TestSession -Token 'BodyTestToken'

            InModuleScope PSSymantecSEPM -Parameters @{ session = $session } {
                $PSVersionTable = @{ PSVersion = [version]'7.0.0' }

                Mock Invoke-RestMethod { return '{"posted":true}' }

                $result = Invoke-SepmApi -Method POST -Uri 'https://SEPM01:8446/sepm/api/v1/resource' `
                    -Body '{"key":"value"}' -ContentType 'application/json' -Session $session

                $result.posted | Should -Be $true

                Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
                    $Method -eq 'POST' -and
                    $Body -eq '{"key":"value"}' -and
                    $ContentType -eq 'application/json'
                }
            }
        }
    }

    Context 'Return type consistency' {
        It 'returns [hashtable] for JSON object response on PS7' {
            $session = New-TestSession -Token 'ReturnTypeToken'

            InModuleScope PSSymantecSEPM -Parameters @{ session = $session } {
                $PSVersionTable = @{ PSVersion = [version]'7.0.0' }

                Mock Invoke-RestMethod { return '{"a":1,"b":2}' }

                $result = Invoke-SepmApi -Method GET -Uri 'https://SEPM01:8446/api' -Session $session

                $result -is [hashtable] | Should -Be $true
                $result.a | Should -Be 1
                $result.b | Should -Be 2
            }
        }

        It 'returns [hashtable] for PSCustomObject responses (already deserialized)' {
            $session = New-TestSession -Token 'PSCustomReturnToken'

            InModuleScope PSSymantecSEPM -Parameters @{ session = $session } {
                $PSVersionTable = @{ PSVersion = [version]'7.0.0' }

                Mock Invoke-RestMethod { return [PSCustomObject]@{ x = 10; y = 20 } }

                $result = Invoke-SepmApi -Method GET -Uri 'https://SEPM01:8446/api' -Session $session

                $result -is [hashtable] | Should -Be $true
                $result.x | Should -Be 10
                $result.y | Should -Be 20
            }
        }
    }
}
