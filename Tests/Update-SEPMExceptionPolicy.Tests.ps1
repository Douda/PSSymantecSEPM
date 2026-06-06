[CmdletBinding()]
param()

Describe 'Update-SEPMExceptionPolicy' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment

        InModuleScope PSSymantecSEPM {
            $script:configurationFilePath = Join-Path -Path 'TestDrive:' -ChildPath 'config.json'
            $script:credentialsFilePath   = Join-Path -Path 'TestDrive:' -ChildPath 'creds.xml'
            $script:accessTokenFilePath   = Join-Path -Path 'TestDrive:' -ChildPath 'token.xml'
        }
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context 'WindowsFile' {
        BeforeEach {
            $script:fakeSession = New-TestSession -SkipCert

            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $script:fakeSession }
            Mock Get-SEPMPoliciesSummary -ModuleName PSSymantecSEPM {
                return New-DummyPolicySummary -PolicyName 'TestPolicy' -PolicyType 'exceptions'
            }
        }

        It 'Adds a file exception with AllScans via PATCH to the API' {
            Mock Invoke-ABRestMethod -ModuleName PSSymantecSEPM {
                return [PSCustomObject]@{ status = 'success' }
            }

            $result = Update-SEPMExceptionPolicy -PolicyName 'TestPolicy' -Path 'C:\test\file.exe' -AllScans

            $result.status | Should -Be 'success'
            Should -Invoke Invoke-ABRestMethod -ModuleName PSSymantecSEPM -Exactly 1 -Scope It
        }

        It 'Adds a file exception with Sonar only' {
            Mock Invoke-ABRestMethod -ModuleName PSSymantecSEPM {
                return [PSCustomObject]@{ status = 'success' }
            }

            $result = Update-SEPMExceptionPolicy -PolicyName 'TestPolicy' -Path 'C:\test\file.exe' -Sonar

            $result.status | Should -Be 'success'
            Should -Invoke Invoke-ABRestMethod -ModuleName PSSymantecSEPM -Exactly 1 -Scope It
            Should -Invoke Invoke-ABRestMethod -ModuleName PSSymantecSEPM -ParameterFilter {
                $params.Method -eq 'PATCH'
            } -Exactly 1 -Scope It
            Should -Invoke Invoke-ABRestMethod -ModuleName PSSymantecSEPM -ParameterFilter {
                ($params.Body | ConvertFrom-Json).configuration.files[0].sonar -eq $true
            } -Exactly 1 -Scope It
        }

        It 'Sets deleted=true on the payload when Remove is specified' {
            Mock Invoke-ABRestMethod -ModuleName PSSymantecSEPM {
                return [PSCustomObject]@{ status = 'success' }
            }

            $result = Update-SEPMExceptionPolicy -PolicyName 'TestPolicy' -Path 'C:\test\file.exe' -Remove

            $result.status | Should -Be 'success'
            Should -Invoke Invoke-ABRestMethod -ModuleName PSSymantecSEPM -ParameterFilter {
                $body = $params.Body | ConvertFrom-Json
                $body.configuration.files[0].deleted -eq $true
            } -Exactly 1 -Scope It
        }

        It 'Defaults to AllScans when no scan type parameter is provided' {
            Mock Invoke-ABRestMethod -ModuleName PSSymantecSEPM {
                return [PSCustomObject]@{ status = 'success' }
            }

            $result = Update-SEPMExceptionPolicy -PolicyName 'TestPolicy' -Path 'C:\test\file.exe'

            $result.status | Should -Be 'success'
            Should -Invoke Invoke-ABRestMethod -ModuleName PSSymantecSEPM -ParameterFilter {
                $body = $params.Body | ConvertFrom-Json
                $file = $body.configuration.files[0]
                $file.sonar -eq $true -and
                $file.securityrisk -eq $true -and
                $file.applicationcontrol -eq $true -and
                $file.scancategory -eq 'AllScans'
            } -Exactly 1 -Scope It
        }

        It 'Rejects an invalid path without file extension' {
            { Update-SEPMExceptionPolicy -PolicyName 'TestPolicy' -Path 'C:\test\folder' -AllScans } |
                Should -Throw -ErrorId "ParameterArgumentValidationError,Update-SEPMExceptionPolicy"
        }
    }

    Context 'WindowsFolder' {
        BeforeEach {
            $script:fakeSession = New-TestSession -SkipCert
            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $script:fakeSession }
            Mock Get-SEPMPoliciesSummary -ModuleName PSSymantecSEPM {
                return New-DummyPolicySummary -PolicyName 'TestPolicy' -PolicyType 'exceptions'
            }
        }

        It 'Adds a folder exception with default All scan type via PATCH' {
            Mock Invoke-ABRestMethod -ModuleName PSSymantecSEPM {
                return [PSCustomObject]@{ status = 'success' }
            }

            $result = Update-SEPMExceptionPolicy -PolicyName 'TestPolicy' -FolderPath 'C:\test'

            $result.status | Should -Be 'success'
            Should -Invoke Invoke-ABRestMethod -ModuleName PSSymantecSEPM -Exactly 1 -Scope It
            Should -Invoke Invoke-ABRestMethod -ModuleName PSSymantecSEPM -ParameterFilter {
                $body = $params.Body | ConvertFrom-Json
                $dir = $body.configuration.directories[0]
                $dir.directory -eq 'C:\test' -and
                $dir.scantype -eq 'All' -and
                $dir.pathvariable -eq '[NONE]'
            } -Exactly 1 -Scope It
        }

        It 'Adds a folder exception with specific ScanType' {
            Mock Invoke-ABRestMethod -ModuleName PSSymantecSEPM {
                return [PSCustomObject]@{ status = 'success' }
            }

            $result = Update-SEPMExceptionPolicy -PolicyName 'TestPolicy' -FolderPath 'C:\test' -ScanType SONAR

            $result.status | Should -Be 'success'
            Should -Invoke Invoke-ABRestMethod -ModuleName PSSymantecSEPM -ParameterFilter {
                $body = $params.Body | ConvertFrom-Json
                $body.configuration.directories[0].scantype -eq 'SONAR'
            } -Exactly 1 -Scope It
        }

        It 'Sets recursive=true when IncludeSubFolders is specified' {
            Mock Invoke-ABRestMethod -ModuleName PSSymantecSEPM {
                return [PSCustomObject]@{ status = 'success' }
            }

            $result = Update-SEPMExceptionPolicy -PolicyName 'TestPolicy' -FolderPath 'C:\test' -IncludeSubFolders

            $result.status | Should -Be 'success'
            Should -Invoke Invoke-ABRestMethod -ModuleName PSSymantecSEPM -ParameterFilter {
                $body = $params.Body | ConvertFrom-Json
                $body.configuration.directories[0].recursive -eq $true
            } -Exactly 1 -Scope It
        }

        It 'Sets deleted=true when Remove is specified' {
            Mock Invoke-ABRestMethod -ModuleName PSSymantecSEPM {
                return [PSCustomObject]@{ status = 'success' }
            }

            $result = Update-SEPMExceptionPolicy -PolicyName 'TestPolicy' -FolderPath 'C:\test' -Remove

            $result.status | Should -Be 'success'
            Should -Invoke Invoke-ABRestMethod -ModuleName PSSymantecSEPM -ParameterFilter {
                $body = $params.Body | ConvertFrom-Json
                $body.configuration.directories[0].deleted -eq $true
            } -Exactly 1 -Scope It
        }

        It 'Throws when SecurityRiskCategory is used without ScanType SecurityRisk' {
            { Update-SEPMExceptionPolicy -PolicyName 'TestPolicy' -FolderPath 'C:\test' -ScanType All -SecurityRiskCategory AllScans } |
                Should -Throw -ExpectedMessage '*SecurityRiskCategory*ScanType*SecurityRisk*'
        }

        It 'Passes SecurityRiskCategory when ScanType is SecurityRisk' {
            Mock Invoke-ABRestMethod -ModuleName PSSymantecSEPM {
                return [PSCustomObject]@{ status = 'success' }
            }

            $result = Update-SEPMExceptionPolicy -PolicyName 'TestPolicy' -FolderPath 'C:\test' -ScanType SecurityRisk -SecurityRiskCategory AutoProtect

            $result.status | Should -Be 'success'
            Should -Invoke Invoke-ABRestMethod -ModuleName PSSymantecSEPM -ParameterFilter {
                $body = $params.Body | ConvertFrom-Json
                $dir = $body.configuration.directories[0]
                $dir.scantype -eq 'SecurityRisk' -and
                $dir.scancategory -eq 'AutoProtect'
            } -Exactly 1 -Scope It
        }
    }

    Context 'WindowsExtension' {
        BeforeEach {
            $script:fakeSession = New-TestSession -SkipCert
            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $script:fakeSession }
            Mock Get-SEPMPoliciesSummary -ModuleName PSSymantecSEPM {
                return New-DummyPolicySummary -PolicyName 'TestPolicy' -PolicyType 'exceptions'
            }
            Mock Get-SEPMExceptionPolicy -ModuleName PSSymantecSEPM {
                return [PSCustomObject]@{
                    configuration = [PSCustomObject]@{
                        extension_list = [PSCustomObject]@{
                            extensions = @('.tmp', '.log')
                            scancategory = 'AllScans'
                        }
                    }
                }
            }
        }

        It 'Adds extensions, merging with existing extensions' {
            Mock Invoke-ABRestMethod -ModuleName PSSymantecSEPM {
                return [PSCustomObject]@{ status = 'success' }
            }

            $result = Update-SEPMExceptionPolicy -PolicyName 'TestPolicy' -Extensions '.exe', '.tmp'

            $result.status | Should -Be 'success'
            Should -Invoke Invoke-ABRestMethod -ModuleName PSSymantecSEPM -Exactly 1 -Scope It
            Should -Invoke Invoke-ABRestMethod -ModuleName PSSymantecSEPM -ParameterFilter {
                $body = $params.Body | ConvertFrom-Json
                $exts = $body.configuration.extension_list.extensions
                $exts.Count -eq 3 -and
                '.exe' -in $exts -and
                '.log' -in $exts -and
                '.tmp' -in $exts
            } -Exactly 1 -Scope It
        }

        It 'Adds extensions, deduplicating when extension already in list' {
            Mock Invoke-ABRestMethod -ModuleName PSSymantecSEPM {
                return [PSCustomObject]@{ status = 'success' }
            }

            $result = Update-SEPMExceptionPolicy -PolicyName 'TestPolicy' -Extensions '.tmp'

            $result.status | Should -Be 'success'
            Should -Invoke Invoke-ABRestMethod -ModuleName PSSymantecSEPM -ParameterFilter {
                $body = $params.Body | ConvertFrom-Json
                $exts = $body.configuration.extension_list.extensions
                $exts.Count -eq 2 -and
                '.log' -in $exts -and
                '.tmp' -in $exts
            } -Exactly 1 -Scope It
        }

        It 'Removes specified extensions from the existing list' {
            Mock Invoke-ABRestMethod -ModuleName PSSymantecSEPM {
                return [PSCustomObject]@{ status = 'success' }
            }

            $result = Update-SEPMExceptionPolicy -PolicyName 'TestPolicy' -Extensions '.tmp' -Remove

            $result.status | Should -Be 'success'
            Should -Invoke Invoke-ABRestMethod -ModuleName PSSymantecSEPM -ParameterFilter {
                $body = $params.Body | ConvertFrom-Json
                $exts = $body.configuration.extension_list.extensions
                $exts.Count -eq 1 -and
                '.log' -in $exts -and
                '.tmp' -notin $exts
            } -Exactly 1 -Scope It
        }

        It 'Throws when removing an extension not in the list' {
            { Update-SEPMExceptionPolicy -PolicyName 'TestPolicy' -Extensions '.exe' -Remove } |
                Should -Throw -ExpectedMessage "*Cannot remove Extension '.exe'*"
        }

        It 'Defaults ScanType to AllScans' {
            Mock Invoke-ABRestMethod -ModuleName PSSymantecSEPM {
                return [PSCustomObject]@{ status = 'success' }
            }

            $result = Update-SEPMExceptionPolicy -PolicyName 'TestPolicy' -Extensions '.exe'

            $result.status | Should -Be 'success'
            Should -Invoke Invoke-ABRestMethod -ModuleName PSSymantecSEPM -ParameterFilter {
                $body = $params.Body | ConvertFrom-Json
                $body.configuration.extension_list.scancategory -eq 'AllScans'
            } -Exactly 1 -Scope It
        }

        It 'Respects explicit ScanType parameter' {
            Mock Invoke-ABRestMethod -ModuleName PSSymantecSEPM {
                return [PSCustomObject]@{ status = 'success' }
            }

            $result = Update-SEPMExceptionPolicy -PolicyName 'TestPolicy' -Extensions '.exe' -ScanType AutoProtect

            $result.status | Should -Be 'success'
            Should -Invoke Invoke-ABRestMethod -ModuleName PSSymantecSEPM -ParameterFilter {
                $body = $params.Body | ConvertFrom-Json
                $body.configuration.extension_list.scancategory -eq 'AutoProtect'
            } -Exactly 1 -Scope It
        }
    }

    Context 'Non-implemented parameter sets' {
        BeforeEach {
            $script:fakeSession = New-TestSession -SkipCert
            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $script:fakeSession }
            Mock Get-SEPMPoliciesSummary -ModuleName PSSymantecSEPM {
                return New-DummyPolicySummary -PolicyName 'TestPolicy' -PolicyType 'exceptions'
            }
        }

        It 'Tamper throws not yet implemented' {
            { Update-SEPMExceptionPolicy -PolicyName 'TestPolicy' -TamperPath 'C:\test\file.exe' } |
                Should -Throw -ExpectedMessage '*Tamper parameter set is not yet implemented*'
        }

        It 'MacFile throws not yet implemented' {
            { Update-SEPMExceptionPolicy -PolicyName 'TestPolicy' -MacPath '/Applications/test.app' } |
                Should -Throw -ExpectedMessage '*MacFile parameter set is not yet implemented*'
        }

        It 'Default throws not yet implemented' {
            { Update-SEPMExceptionPolicy -PolicyName 'TestPolicy' } |
                Should -Throw -ExpectedMessage '*No parameter set specified*'
        }
    }
}
