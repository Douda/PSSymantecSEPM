[CmdletBinding()]
param()

Describe 'Start-SEPMReplication' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context 'happy path' {
        BeforeAll {
            $script:fakeSession = Set-TestMocks -Transport {
                return @{ code = 0; message = 'Replication initiated' }
            }
        }

        It 'sends POST to /replication/replicatenow' {
            Start-SEPMReplication -partnerSiteName 'RemoteSiteAmericas'

            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'POST' -and $Uri -match '/replication/replicatenow'
            }
        }

        It 'includes partnerSiteName in query string' {
            Start-SEPMReplication -partnerSiteName 'RemoteSiteEurope'

            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Times 1 -Exactly -ParameterFilter {
                $Uri -match 'partnerSiteName=RemoteSiteEurope'
            }
        }

        It 'returns the Invoke-SepmApi response' {
            $result = Start-SEPMReplication -partnerSiteName 'RemoteSiteAsia' -PassThru

            $result.code    | Should -Be 0
            $result.message | Should -Be 'Replication initiated'
        }

        It 'suppresses output when -PassThru is not specified' {
            $result = Start-SEPMReplication -partnerSiteName 'RemoteSiteAsia'

            $result | Should -BeNullOrEmpty
        }

        It 'can be called without partnerSiteName parameter' {
            Start-SEPMReplication

            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'POST'
            }
        }

        It 'URI includes base path for replication endpoint' {
            Start-SEPMReplication -partnerSiteName 'PartnerX'

            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Times 1 -Exactly -ParameterFilter {
                $Uri -match ([regex]::Escape($script:fakeSession.BaseURLv1 + '/replication/replicatenow'))
            }
        }
    }

    Context 'URI construction' {
        BeforeAll {
            $script:fakeSession = Set-TestMocks -Transport {
                return @{ code = 0 }
            }
        }

        It 'uses the configured server address from session' {
            Start-SEPMReplication -partnerSiteName 'SiteA'

            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Times 1 -Exactly -ParameterFilter {
                $Uri -match ([regex]::Escape($script:fakeSession.BaseURLv1))
            }
        }
    }
}
