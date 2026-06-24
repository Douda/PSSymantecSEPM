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
            $fakeSession = New-TestSession
            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }

            $script:apiCalls = @()
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                $script:apiCalls += [PSCustomObject]@{
                    Method = $Method
                    Uri    = $Uri
                }
                return @{ code = 0; message = 'Replication initiated' }
            }
        }

        It 'sends POST to /replication/replicatenow' {
            Start-SEPMReplication -partnerSiteName 'RemoteSiteAmericas'

            $script:apiCalls.Count | Should -Be 1
            $script:apiCalls[0].Method | Should -Be 'POST'
            $script:apiCalls[0].Uri    | Should -Match '/replication/replicatenow'
        }

        It 'includes partnerSiteName in query string' {
            Start-SEPMReplication -partnerSiteName 'RemoteSiteEurope'

            $script:apiCalls.Count | Should -Be 2
            $script:apiCalls[1].Uri | Should -Match 'partnerSiteName=RemoteSiteEurope'
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

            $script:apiCalls.Count | Should -Be 5
            $script:apiCalls[4].Method | Should -Be 'POST'
        }

        It 'URI includes base path for replication endpoint' {
            Start-SEPMReplication -partnerSiteName 'PartnerX'

            $script:apiCalls[0].Uri | Should -Match ([regex]::Escape($fakeSession.BaseURLv1 + '/replication/replicatenow'))
        }
    }

    Context 'URI construction' {
        BeforeAll {
            $fakeSession = New-TestSession -ServerAddress 'sepm.example.com' -Port '8446'
            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }

            $script:apiCalls = @()
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                $script:apiCalls += [PSCustomObject]@{
                    Method = $Method
                    Uri    = $Uri
                }
                return @{ code = 0 }
            }
        }

        It 'uses the configured server address from session' {
            Start-SEPMReplication -partnerSiteName 'SiteA'

            $script:apiCalls[0].Uri | Should -Match ([regex]::Escape($fakeSession.BaseURLv1))
        }
    }
}
