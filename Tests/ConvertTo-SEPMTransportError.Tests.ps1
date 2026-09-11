[CmdletBinding()]
param()

Describe 'ConvertTo-SEPMTransportError' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context 'certificate failures' {
        It 'tags an inner AuthenticationException as SEPM.CertificateError' {
            InModuleScope PSSymantecSEPM {
                # The shape PS 7 produces: HttpRequestException wrapping AuthenticationException.
                $inner = [System.Security.Authentication.AuthenticationException]::new(
                    'The remote certificate is invalid according to the validation procedure: RemoteCertificateNameMismatch')
                $outer = [System.Net.Http.HttpRequestException]::new(
                    'The SSL connection could not be established, see inner exception.', $inner)

                $errorRecord = ConvertTo-SEPMTransportError -Exception $outer -Method GET `
                    -Uri 'https://sepm.example.com:8446/sepm/api/v1/version'

                $errorRecord.FullyQualifiedErrorId | Should -BeLike 'SEPM.CertificateError*'
                $errorRecord.CategoryInfo.Category | Should -Be 'SecurityError'
                # The innermost message is the specific one, not "see inner exception".
                $errorRecord.Exception.Message | Should -Match 'RemoteCertificateNameMismatch'
            }
        }

        It 'tags an AuthenticationException wrapped in a WebException as SEPM.CertificateError' {
            InModuleScope PSSymantecSEPM {
                # The shape PS 5.1 produces: the TLS handshake aborts the request, and the
                # AuthenticationException ends up inside a WebException.
                $inner = [System.Security.Authentication.AuthenticationException]::new(
                    'The remote certificate is invalid according to the validation procedure.')
                $outer = [System.Net.WebException]::new(
                    'The underlying connection was closed: Could not establish trust relationship for the SSL/TLS secure channel.', $inner)

                $errorRecord = ConvertTo-SEPMTransportError -Exception $outer -Method POST `
                    -Uri 'https://sepm.example.com:8446/sepm/api/v1/identity/authenticate'

                $errorRecord.FullyQualifiedErrorId | Should -BeLike 'SEPM.CertificateError*'
                $errorRecord.CategoryInfo.Category | Should -Be 'SecurityError'
                # The innermost message is the specific one, not "the underlying connection was closed".
                $errorRecord.Exception.Message | Should -Match 'remote certificate is invalid'
            }
        }

        It 'falls back to the message when no AuthenticationException is in the chain' {
            InModuleScope PSSymantecSEPM {
                $ex = [System.Exception]::new('The remote certificate is invalid according to the validation procedure')
                $errorRecord = ConvertTo-SEPMTransportError -Exception $ex -Method GET -Uri 'https://sepm/api'

                $errorRecord.FullyQualifiedErrorId | Should -BeLike 'SEPM.CertificateError*'
            }
        }

        It 'reports the certificate failure in preference to any body' {
            InModuleScope PSSymantecSEPM {
                $ex = [System.Security.Authentication.AuthenticationException]::new('cert bad')
                $errorRecord = ConvertTo-SEPMTransportError -Exception $ex -Method GET -Uri 'https://sepm/api' `
                    -StatusCode 0 -Body '{"errorCode":"401","errorMessage":"should be ignored"}'

                $errorRecord.FullyQualifiedErrorId | Should -BeLike 'SEPM.CertificateError*'
                $errorRecord.Exception.Message | Should -Not -Match 'should be ignored'
            }
        }
    }

    Context 'SEPM error body shapes' {
        It 'reads errorMessage from the application error shape' {
            InModuleScope PSSymantecSEPM {
                $ex = [System.Exception]::new('boom')
                $errorRecord = ConvertTo-SEPMTransportError -Exception $ex -Method GET `
                    -Uri 'https://sepm/api/computers/x' -StatusCode 500 `
                    -Body '{"errorCode":"500","appErrorCode":"","errorMessage":"Internal Server Error"}'

                $errorRecord.Exception.Message | Should -Match 'Internal Server Error'
                $errorRecord.Exception.Message | Should -Match '\(HTTP 500\)'
                $errorRecord.FullyQualifiedErrorId | Should -BeLike 'SEPM.ApiError*'
            }
        }

        It 'reads error_description from the authentication shape and tags SEPM.AuthenticationFailed' {
            InModuleScope PSSymantecSEPM {
                $ex = [System.Exception]::new('boom')
                $errorRecord = ConvertTo-SEPMTransportError -Exception $ex -Method GET `
                    -Uri 'https://sepm/api/computers' -StatusCode 401 `
                    -Body '{"error":"invalid_token","error_description":"Invalid access token: garbage"}'

                $errorRecord.FullyQualifiedErrorId | Should -BeLike 'SEPM.AuthenticationFailed*'
                $errorRecord.CategoryInfo.Category | Should -Be 'AuthenticationError'
                $errorRecord.Exception.Message | Should -Match 'Invalid access token: garbage'
            }
        }

        It 'names an HTML error page instead of pasting its markup' {
            InModuleScope PSSymantecSEPM {
                $ex = [System.Exception]::new('boom')
                $html = '<!doctype html><html><head><title>HTTP Status 404 – Not Found</title>' +
                        '<style type="text/css">body {font-family:Tahoma,Arial,sans-serif;}</style></head>' +
                        '<body><h1>HTTP Status 404 – Not Found</h1></body></html>'

                $errorRecord = ConvertTo-SEPMTransportError -Exception $ex -Method GET `
                    -Uri 'https://sepm/api/nope' -StatusCode 404 -Body $html

                $errorRecord.Exception.Message | Should -Match 'HTML error page'
                $errorRecord.Exception.Message | Should -Not -Match 'font-family'
                $errorRecord.CategoryInfo.Category | Should -Be 'ObjectNotFound'
            }
        }

        It 'also handles the tag-stripped page PS 7 hands over' {
            InModuleScope PSSymantecSEPM {
                $ex = [System.Exception]::new('boom')
                # PS 7 strips the tags itself, so the page arrives as plain text.
                $stripped = 'HTTP Status 404 – Not Foundbody {font-family:Tahoma,Arial,sans-serif;} h1 {color:white;}'

                $errorRecord = ConvertTo-SEPMTransportError -Exception $ex -Method GET `
                    -Uri 'https://sepm/api/nope' -StatusCode 404 -Body $stripped

                $errorRecord.Exception.Message | Should -Match 'HTML error page'
                $errorRecord.Exception.Message | Should -Not -Match 'font-family'
            }
        }

        It 'truncates a long non-JSON body' {
            InModuleScope PSSymantecSEPM {
                $ex = [System.Exception]::new('boom')
                $errorRecord = ConvertTo-SEPMTransportError -Exception $ex -Method GET `
                    -Uri 'https://sepm/api' -StatusCode 400 -Body ('x' * 1000)

                $errorRecord.Exception.Message | Should -Match 'truncated'
                $errorRecord.Exception.Message.Length | Should -BeLessThan 600
            }
        }
    }

    Context 'category mapping' {
        It 'maps <status> to <category>' -TestCases @(
            @{ status = 400; category = 'InvalidData' }
            @{ status = 403; category = 'PermissionDenied' }
            @{ status = 404; category = 'ObjectNotFound' }
            @{ status = 422; category = 'InvalidData' }
            @{ status = 429; category = 'LimitsExceeded' }
            @{ status = 500; category = 'ResourceUnavailable' }
            @{ status = 503; category = 'ResourceUnavailable' }
        ) {
            param($status, $category)
            InModuleScope PSSymantecSEPM -Parameters @{ status = $status; category = $category } {
                $ex = [System.Exception]::new('boom')
                $errorRecord = ConvertTo-SEPMTransportError -Exception $ex -Method GET `
                    -Uri 'https://sepm/api' -StatusCode $status

                $errorRecord.CategoryInfo.Category | Should -Be $category
            }
        }

        It 'maps a request that never received a response to ConnectionError' {
            InModuleScope PSSymantecSEPM {
                $ex = [System.Exception]::new('Connection refused')
                $errorRecord = ConvertTo-SEPMTransportError -Exception $ex -Method GET -Uri 'https://sepm/api'

                $errorRecord.CategoryInfo.Category | Should -Be 'ConnectionError'
                $errorRecord.Exception.Message | Should -Match 'Connection refused'
            }
        }

        It 'prefers the body errorCode over the HTTP status when they disagree' {
            InModuleScope PSSymantecSEPM {
                # Defensive: SEPM's codes currently always agree with its status, but the rule is
                # that the body wins, and the disagreement is surfaced in the message.
                $ex = [System.Exception]::new('boom')
                $errorRecord = ConvertTo-SEPMTransportError -Exception $ex -Method GET -Uri 'https://sepm/api' `
                    -StatusCode 500 -Body '{"errorCode":"400","errorMessage":"bad input"}'

                $errorRecord.CategoryInfo.Category | Should -Be 'InvalidData'
                $errorRecord.Exception.Message | Should -Match 'HTTP 500, SEPM code 400'
            }
        }
    }

    Context 'message composition' {
        It 'names the method and the request path' {
            InModuleScope PSSymantecSEPM {
                $ex = [System.Exception]::new('boom')
                $errorRecord = ConvertTo-SEPMTransportError -Exception $ex -Method PATCH `
                    -Uri 'https://sepm.example.com:8446/sepm/api/v2/policies/exceptions/ABC123' -StatusCode 500

                $errorRecord.Exception.Message | Should -Match '^SEPM API PATCH /sepm/api/v2/policies/exceptions/ABC123 failed'
            }
        }

        It 'attaches the full URI as the error target' {
            InModuleScope PSSymantecSEPM {
                $ex = [System.Exception]::new('boom')
                $errorRecord = ConvertTo-SEPMTransportError -Exception $ex -Method GET `
                    -Uri 'https://sepm.example.com:8446/sepm/api/v1/version' -StatusCode 500

                $errorRecord.TargetObject | Should -Be 'https://sepm.example.com:8446/sepm/api/v1/version'
            }
        }

        It 'shows only the SEPM code when there is no HTTP status' {
            InModuleScope PSSymantecSEPM {
                $ex = [System.Exception]::new('boom')
                $errorRecord = ConvertTo-SEPMTransportError -Exception $ex -Method GET -Uri 'https://sepm/api' `
                    -Body '{"errorCode":"400","errorMessage":"bad input"}'

                $errorRecord.Exception.Message | Should -Match '\(SEPM code 400\)'
                $errorRecord.Exception.Message | Should -Not -Match 'HTTP'
            }
        }
    }
}
