[CmdletBinding()]
param()

Describe 'Invoke-SepmEndpoint' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context 'dispatch to transport' {
        BeforeAll {
            $fakeSession = New-TestSession -ServerAddress 'sepm.example.com' -Port '8446' -Token 'abc123'

            $endpoint = @{
                OperationName = 'Get-SEPMVersion'
                Version       = '1.0'
                Method        = 'GET'
                Path          = '/version'
            }
        }

        It 'calls Invoke-SepmApi with resolved URI, Method, and Session' {
            InModuleScope PSSymantecSEPM -Parameters @{ Endpoint = $endpoint; Session = $fakeSession } {
                Mock Invoke-SepmApi { return @{ ok = $true } }

                $result = Invoke-SepmEndpoint -Endpoint $Endpoint -Session $Session

                $result.ok | Should -Be $true

                Should -Invoke Invoke-SepmApi -Times 1 -Exactly -ParameterFilter {
                    $Method -eq 'GET' -and
                    $Uri -eq 'https://sepm.example.com:8446/sepm/api/v1/version' -and
                    $null -ne $Session -and
                    $Session.Headers.Authorization -eq 'Bearer abc123'
                }
            }
        }

        It 'returns the result from Invoke-SepmApi' {
            InModuleScope PSSymantecSEPM -Parameters @{ Endpoint = $endpoint; Session = $fakeSession } {
                Mock Invoke-SepmApi {
                    return @{
                        API_SEQUENCE = '230504014'
                        API_VERSION  = '14.3.7000'
                        version      = '14.3.9816.7000'
                    }
                }

                $result = Invoke-SepmEndpoint -Endpoint $Endpoint -Session $Session

                $result.API_SEQUENCE | Should -Be '230504014'
                $result.API_VERSION  | Should -Be '14.3.7000'
                $result.version      | Should -Be '14.3.9816.7000'
            }
        }
    }

    Context 'BodyParams resolution' {
        BeforeAll {
            $fakeSession = New-TestSession -ServerAddress 'sepm.example.com' -Port '8446' -Token 'abc123'

            $endpointWithBodyParams = @{
                OperationName = 'New-SEPMGroup'
                Version       = '1.0'
                Method        = 'POST'
                Path          = '/groups'
                BodyParams    = @{
                    name        = 'GroupName'
                    description = 'Description'
                    inherits    = 'EnabledInheritance'
                }
            }

            $endpointSwitchOnly = @{
                OperationName = 'New-SEPMGroup'
                Version       = '1.0'
                Method        = 'POST'
                Path          = '/groups'
                BodyParams    = @{ inherits = 'EnabledInheritance' }
            }

            $endpointNoInherits = @{
                OperationName = 'New-SEPMGroup'
                Version       = '1.0'
                Method        = 'POST'
                Path          = '/groups'
                BodyParams    = @{
                    name        = 'GroupName'
                    description = 'Description'
                }
            }

            $script:mockBody = $null
            $script:mockContentType = $null

            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                $script:mockBody = $Body
                $script:mockContentType = $ContentType
                return @{ id = 'new-id'; name = 'Win7' }
            }
        }

        It 'auto-builds flat body from BodyParams and passes as JSON to Invoke-SepmApi' {
            $boundParams = @{
                GroupName          = 'Win7'
                Description        = 'Test group'
                EnabledInheritance = $false
            }

            $script:mockBody = $null
            $script:mockContentType = $null

            InModuleScope PSSymantecSEPM -Parameters @{ Endpoint = $endpointWithBodyParams; Session = $fakeSession; BoundParams = $boundParams } {
                Invoke-SepmEndpoint -Endpoint $Endpoint -Session $Session -BoundParameters $BoundParams
            }

            $script:mockBody | Should -Not -BeNullOrEmpty
            $script:mockContentType | Should -Be 'application/json'
            $bodyObj = $script:mockBody | ConvertFrom-Json
            $bodyObj.name        | Should -Be 'Win7'
            $bodyObj.description | Should -Be 'Test group'
            $bodyObj.inherits    | Should -BeFalse
        }

        It 'converts switch parameter to boolean in body' {
            $boundParams = @{ EnabledInheritance = $true }

            $script:mockBody = $null

            InModuleScope PSSymantecSEPM -Parameters @{ Endpoint = $endpointSwitchOnly; Session = $fakeSession; BoundParams = $boundParams } {
                Invoke-SepmEndpoint -Endpoint $Endpoint -Session $Session -BoundParameters $BoundParams
            }

            $bodyObj = $script:mockBody | ConvertFrom-Json
            $bodyObj.inherits | Should -BeTrue
        }

        It 'omits null and empty string values from body' {
            $boundParams = @{ GroupName = 'Test'; Description = '' }

            $script:mockBody = $null

            InModuleScope PSSymantecSEPM -Parameters @{ Endpoint = $endpointNoInherits; Session = $fakeSession; BoundParams = $boundParams } {
                Invoke-SepmEndpoint -Endpoint $Endpoint -Session $Session -BoundParameters $BoundParams
            }

            $bodyObj = $script:mockBody | ConvertFrom-Json
            $bodyObj.name | Should -Be 'Test'
            $bodyObj.PSObject.Properties.Name | Should -Not -Contain 'description'
        }
    }

    Context 'paginated branch' {
        BeforeAll {
            $fakeSession = New-TestSession -ServerAddress 'sepm.example.com' -Port '8446' -Token 'abc123'

            $script:pagedEndpoint = @{
                OperationName = 'Get-SEPMComputers'
                Version       = '1.0'
                Method        = 'GET'
                Path          = '/computers'
                Paginated     = $true
                PageDefaults  = @{ sort = 'COMPUTER_NAME'; pageSize = 100 }
            }

            $script:nonPagedEndpoint = @{
                OperationName = 'Get-SEPMVersion'
                Version       = '1.0'
                Method        = 'GET'
                Path          = '/version'
            }
        }

        It 'delegates to Invoke-SepmApiPaginated when Paginated = $true' {
            InModuleScope PSSymantecSEPM -Parameters @{ Endpoint = $script:pagedEndpoint; Session = $fakeSession } {
                Mock Invoke-SepmApiPaginated {
                    return @('PC1', 'PC2')
                }

                $result = Invoke-SepmEndpoint -Endpoint $Endpoint -Session $Session

                # Result is the concatenated array directly
                $result.Count | Should -Be 2
                $result[0] | Should -Be 'PC1'
                $result[1] | Should -Be 'PC2'

                Should -Invoke Invoke-SepmApiPaginated -Times 1 -Exactly
            }
        }

        It 'does NOT delegate to Invoke-SepmApiPaginated when Paginated is not set' {
            InModuleScope PSSymantecSEPM -Parameters @{ Endpoint = $script:nonPagedEndpoint; Session = $fakeSession } {
                Mock Invoke-SepmApi { return @{ ok = $true } }
                Mock Invoke-SepmApiPaginated {
                    return @()
                }

                $result = Invoke-SepmEndpoint -Endpoint $Endpoint -Session $Session

                $result.ok | Should -Be $true
                Should -Invoke Invoke-SepmApiPaginated -Times 0 -Exactly
            }
        }
    }
}
