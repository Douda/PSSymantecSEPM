[CmdletBinding()]
param()

Describe 'Get-SEPMDatabaseInfo' {
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
        }

        It 'returns database info with expected keys' {
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                return @{
                    name                 = 'SQLSRV01'
                    description          = ''
                    address              = 'SQLSRV01'
                    instanceName         = ''
                    port                 = 1433
                    type                 = 'Microsoft SQL Server'
                    version              = '12.00.5000'
                    installedBySepm      = $false
                    database             = 'sem5'
                    dbUser               = 'sem5'
                    dbPasswords          = $null
                    dbTLSRootCertificate = ''
                }
            }

            $result = Get-SEPMDatabaseInfo
            $result.name    | Should -Be 'SQLSRV01'
            $result.port    | Should -Be 1433
            $result.database | Should -Be 'sem5'
            $result.type    | Should -Be 'Microsoft SQL Server'
        }

        It 'calls the correct API endpoint' {
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM { return @{ ok = $true } }

            Get-SEPMDatabaseInfo | Out-Null
            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'GET' -and $Uri -match '/admin/database$'
            }
        }

        It 'handles response with null fields gracefully' {
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                return @{
                    name      = 'DB01'
                    dbPasswords = $null
                    description = $null
                    dbTLSRootCertificate = $null
                }
            }

            $result = Get-SEPMDatabaseInfo
            $result.name | Should -Be 'DB01'
            $result.dbPasswords | Should -BeNullOrEmpty
        }
    }
}
