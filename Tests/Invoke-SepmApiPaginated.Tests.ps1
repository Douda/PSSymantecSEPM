[CmdletBinding()]
param()

Describe 'Invoke-SepmApiPaginated' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment

        $script:fakeSession = New-TestSession -ServerAddress 'sepm.example.com' -Port '8446' -Token 'abc123'

        $script:pagedEndpoint = @{
            OperationName = 'Get-SEPMComputers'
            Version       = '1.0'
            Method        = 'GET'
            Path          = '/computers'
            Paginated     = $true
            PageDefaults  = @{ sort = 'COMPUTER_NAME'; pageSize = 100 }
        }
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context 'single page' {
        It 'returns content from a single page' {
            InModuleScope PSSymantecSEPM -Parameters @{ Endpoint = $script:pagedEndpoint; Session = $script:fakeSession } {
                Mock Invoke-SepmApi {
                    return @{
                        content   = @(
                            @{ computerName = 'PC1' }
                            @{ computerName = 'PC2' }
                        )
                        lastPage  = $true
                        firstPage = $true
                    }
                }

                Mock Resolve-SepmEndpoint { return 'https://sepm.example.com:8446/sepm/api/v1/computers?pageIndex=1&sort=COMPUTER_NAME&pageSize=100' }

                $result = Invoke-SepmApiPaginated -Endpoint $Endpoint -Session $Session

                $result | Should -Not -BeNullOrEmpty
                $result.Count | Should -Be 2
                $result[0].computerName | Should -Be 'PC1'
                $result[1].computerName | Should -Be 'PC2'
            }
        }
    }

    Context 'multi-page' {
        It 'concatenates content from multiple pages' {
            InModuleScope PSSymantecSEPM -Parameters @{ Endpoint = $script:pagedEndpoint; Session = $script:fakeSession } {
                $script:callCount = 0
                Mock Invoke-SepmApi {
                    $script:callCount++
                    if ($script:callCount -ge 2) {
                        return @{
                            content   = @(
                                @{ computerName = 'PC3' }
                            )
                            lastPage  = $true
                            firstPage = $false
                        }
                    } else {
                        return @{
                            content   = @(
                                @{ computerName = 'PC1' }
                                @{ computerName = 'PC2' }
                            )
                            lastPage  = $false
                            firstPage = $true
                        }
                    }
                }

                Mock Resolve-SepmEndpoint { return 'https://sepm.example.com:8446/sepm/api/v1/computers' }

                $result = Invoke-SepmApiPaginated -Endpoint $Endpoint -Session $Session

                $result | Should -Not -BeNullOrEmpty
                $result.Count | Should -Be 3
                $result[0].computerName | Should -Be 'PC1'
                $result[1].computerName | Should -Be 'PC2'
                $result[2].computerName | Should -Be 'PC3'
                $script:callCount | Should -Be 2
            }
        }
    }

    Context 'PageDefaults merge' {
        It 'merges PageDefaults into query params on first call' {
            InModuleScope PSSymantecSEPM -Parameters @{ Endpoint = $script:pagedEndpoint; Session = $script:fakeSession } {
                $script:resolvedParams = $null
                Mock Resolve-SepmEndpoint {
                    # Clone hashtable to capture a snapshot (not a reference)
                    $clone = @{}
                    foreach ($key in $AdditionalQueryParams.Keys) { $clone[$key] = $AdditionalQueryParams[$key] }
                    $script:resolvedParams = $clone
                    return 'https://sepm.example.com:8446/sepm/api/v1/computers'
                }

                Mock Invoke-SepmApi {
                    return @{
                        content   = @(@{ computerName = 'PC1' })
                        lastPage  = $true
                        firstPage = $true
                    }
                }

                $result = Invoke-SepmApiPaginated -Endpoint $Endpoint -Session $Session

                $script:resolvedParams | Should -Not -BeNullOrEmpty
                $script:resolvedParams.sort | Should -Be 'COMPUTER_NAME'
                $script:resolvedParams.pageSize | Should -Be 100
                $script:resolvedParams.pageIndex | Should -Be 1
            }
        }
    }

    Context 'error handling' {
        It 'throws when Invoke-SepmApi returns an error string' {
            InModuleScope PSSymantecSEPM -Parameters @{ Endpoint = $script:pagedEndpoint; Session = $script:fakeSession } {
                Mock Invoke-SepmApi {
                    return 'Error: Something went wrong'
                }

                Mock Resolve-SepmEndpoint { return 'https://sepm.example.com:8446/sepm/api/v1/computers' }

                { Invoke-SepmApiPaginated -Endpoint $Endpoint -Session $Session } | Should -Throw
            }
        }
    }

    Context 'non-paginated endpoint' {
        It 'throws descriptive error if called for non-paginated endpoint' {
            $nonPagedEndpoint = @{
                OperationName = 'Get-SEPMVersion'
                Version       = '1.0'
                Method        = 'GET'
                Path          = '/version'
            }
            InModuleScope PSSymantecSEPM -Parameters @{ Endpoint = $nonPagedEndpoint; Session = $script:fakeSession } {
                { Invoke-SepmApiPaginated -Endpoint $Endpoint -Session $Session } | Should -Throw '*not configured for pagination*'
            }
        }
    }

    Context 'Write-Progress' {
        It 'emits Write-Progress during multi-page fetches with totalPages' {
            InModuleScope PSSymantecSEPM -Parameters @{ Endpoint = $script:pagedEndpoint; Session = $script:fakeSession } {
                $script:callCount = 0
                $script:progressCalls = @()
                Mock Write-Progress -ModuleName PSSymantecSEPM {
                    $script:progressCalls += @{
                        Activity        = $Activity
                        Status          = $Status
                        PercentComplete = $PercentComplete
                        Completed       = $Completed.IsPresent
                    }
                }

                Mock Invoke-SepmApi {
                    $script:callCount++
                    if ($script:callCount -eq 1) {
                        return @{
                            content     = @( @{ computerName = 'PC1' }, @{ computerName = 'PC2' } )
                            lastPage    = $false
                            firstPage   = $true
                            totalPages  = 2
                        }
                    } else {
                        return @{
                            content     = @( @{ computerName = 'PC3' } )
                            lastPage    = $true
                            firstPage   = $false
                            totalPages  = 2
                        }
                    }
                }

                Mock Resolve-SepmEndpoint { return 'https://sepm.example.com:8446/sepm/api/v1/computers' }

                $null = Invoke-SepmApiPaginated -Endpoint $Endpoint -Session $Session

                $script:progressCalls | Should -Not -BeNullOrEmpty
                # Count non-completed progress calls with valid percent
                $progressCount = @($script:progressCalls | Where-Object { $_.Activity -eq 'Get-SEPMComputers' -and $_.Completed -eq $false }).Count
                $progressCount | Should -BeGreaterThan 0
            }
        }

        It 'skips progress for single-page fetches' {
            InModuleScope PSSymantecSEPM -Parameters @{ Endpoint = $script:pagedEndpoint; Session = $script:fakeSession } {
                $script:progressCalls = @()
                Mock Write-Progress -ModuleName PSSymantecSEPM {
                    $script:progressCalls += @{ Activity = $Activity; PercentComplete = $PercentComplete; Completed = $Completed.IsPresent }
                }

                Mock Invoke-SepmApi {
                    return @{
                        content    = @( @{ computerName = 'PC1' } )
                        lastPage   = $true
                        firstPage  = $true
                        totalPages = 1
                    }
                }

                Mock Resolve-SepmEndpoint { return 'https://sepm.example.com:8446/sepm/api/v1/computers' }

                $null = Invoke-SepmApiPaginated -Endpoint $Endpoint -Session $Session

                # Should have only the -Completed call, no non-completed progress calls
                $nonCompletedCalls = @($script:progressCalls | Where-Object { $_.Completed -eq $false })
                $nonCompletedCalls.Count | Should -Be 0

                # Should have a -Completed call to clear the progress bar
                $completedCalls = @($script:progressCalls | Where-Object { $_.Completed -eq $true })
                $completedCalls.Count | Should -Be 1
            }
        }
    }
}
