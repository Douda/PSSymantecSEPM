[CmdletBinding()]
param()

Describe 'Update-SEPMExceptionPolicy' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment
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
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                return [PSCustomObject]@{ status = 'success' }
            }

            $result = Update-SEPMExceptionPolicy -PolicyName 'TestPolicy' -Path 'C:\test\file.exe' -AllScans

            $result.status | Should -Be 'success'
            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Exactly 1 -Scope It
        }

        It 'Adds a file exception with Sonar only' {
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                return [PSCustomObject]@{ status = 'success' }
            }

            $result = Update-SEPMExceptionPolicy -PolicyName 'TestPolicy' -Path 'C:\test\file.exe' -Sonar

            $result.status | Should -Be 'success'
            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Exactly 1 -Scope It
            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -ParameterFilter {
                $Method -eq 'PATCH'
            } -Exactly 1 -Scope It
            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -ParameterFilter {
                ($Body | ConvertFrom-Json).configuration.files[0].sonar -eq $true
            } -Exactly 1 -Scope It
        }

        It 'Sets deleted=true on the payload when Remove is specified' {
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                return [PSCustomObject]@{ status = 'success' }
            }

            $result = Update-SEPMExceptionPolicy -PolicyName 'TestPolicy' -Path 'C:\test\file.exe' -Remove

            $result.status | Should -Be 'success'
            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -ParameterFilter {
                $body = $Body | ConvertFrom-Json
                $body.configuration.files[0].deleted -eq $true
            } -Exactly 1 -Scope It
        }

        It 'Defaults to AllScans when no scan type parameter is provided' {
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                return [PSCustomObject]@{ status = 'success' }
            }

            $result = Update-SEPMExceptionPolicy -PolicyName 'TestPolicy' -Path 'C:\test\file.exe'

            $result.status | Should -Be 'success'
            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -ParameterFilter {
                $body = $Body | ConvertFrom-Json
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
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                return [PSCustomObject]@{ status = 'success' }
            }

            $result = Update-SEPMExceptionPolicy -PolicyName 'TestPolicy' -FolderPath 'C:\test'

            $result.status | Should -Be 'success'
            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Exactly 1 -Scope It
            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -ParameterFilter {
                $body = $Body | ConvertFrom-Json
                $dir = $body.configuration.directories[0]
                $dir.directory -eq 'C:\test' -and
                $dir.scantype -eq 'All' -and
                $dir.pathvariable -eq '[NONE]'
            } -Exactly 1 -Scope It
        }

        It 'Adds a folder exception with specific ScanType' {
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                return [PSCustomObject]@{ status = 'success' }
            }

            $result = Update-SEPMExceptionPolicy -PolicyName 'TestPolicy' -FolderPath 'C:\test' -ScanType SONAR

            $result.status | Should -Be 'success'
            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -ParameterFilter {
                $body = $Body | ConvertFrom-Json
                $body.configuration.directories[0].scantype -eq 'SONAR'
            } -Exactly 1 -Scope It
        }

        It 'Sets recursive=true when IncludeSubFolders is specified' {
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                return [PSCustomObject]@{ status = 'success' }
            }

            $result = Update-SEPMExceptionPolicy -PolicyName 'TestPolicy' -FolderPath 'C:\test' -IncludeSubFolders

            $result.status | Should -Be 'success'
            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -ParameterFilter {
                $body = $Body | ConvertFrom-Json
                $body.configuration.directories[0].recursive -eq $true
            } -Exactly 1 -Scope It
        }

        It 'Sets deleted=true when Remove is specified' {
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                return [PSCustomObject]@{ status = 'success' }
            }

            $result = Update-SEPMExceptionPolicy -PolicyName 'TestPolicy' -FolderPath 'C:\test' -Remove

            $result.status | Should -Be 'success'
            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -ParameterFilter {
                $body = $Body | ConvertFrom-Json
                $body.configuration.directories[0].deleted -eq $true
            } -Exactly 1 -Scope It
        }

        It 'Throws when SecurityRiskCategory is used without ScanType SecurityRisk' {
            { Update-SEPMExceptionPolicy -PolicyName 'TestPolicy' -FolderPath 'C:\test' -ScanType All -SecurityRiskCategory AllScans } |
                Should -Throw -ExpectedMessage '*SecurityRiskCategory*ScanType*SecurityRisk*'
        }

        It 'Passes SecurityRiskCategory when ScanType is SecurityRisk' {
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                return [PSCustomObject]@{ status = 'success' }
            }

            $result = Update-SEPMExceptionPolicy -PolicyName 'TestPolicy' -FolderPath 'C:\test' -ScanType SecurityRisk -SecurityRiskCategory AutoProtect

            $result.status | Should -Be 'success'
            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -ParameterFilter {
                $body = $Body | ConvertFrom-Json
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
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                return [PSCustomObject]@{ status = 'success' }
            }

            $result = Update-SEPMExceptionPolicy -PolicyName 'TestPolicy' -Extensions '.exe', '.tmp'

            $result.status | Should -Be 'success'
            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Exactly 1 -Scope It
            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -ParameterFilter {
                $body = $Body | ConvertFrom-Json
                $exts = $body.configuration.extension_list.extensions
                $exts.Count -eq 3 -and
                '.exe' -in $exts -and
                '.log' -in $exts -and
                '.tmp' -in $exts
            } -Exactly 1 -Scope It
        }

        It 'Adds extensions, deduplicating when extension already in list' {
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                return [PSCustomObject]@{ status = 'success' }
            }

            $result = Update-SEPMExceptionPolicy -PolicyName 'TestPolicy' -Extensions '.tmp'

            $result.status | Should -Be 'success'
            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -ParameterFilter {
                $body = $Body | ConvertFrom-Json
                $exts = $body.configuration.extension_list.extensions
                $exts.Count -eq 2 -and
                '.log' -in $exts -and
                '.tmp' -in $exts
            } -Exactly 1 -Scope It
        }

        It 'Removes specified extensions from the existing list' {
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                return [PSCustomObject]@{ status = 'success' }
            }

            $result = Update-SEPMExceptionPolicy -PolicyName 'TestPolicy' -Extensions '.tmp' -Remove

            $result.status | Should -Be 'success'
            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -ParameterFilter {
                $body = $Body | ConvertFrom-Json
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
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                return [PSCustomObject]@{ status = 'success' }
            }

            $result = Update-SEPMExceptionPolicy -PolicyName 'TestPolicy' -Extensions '.exe'

            $result.status | Should -Be 'success'
            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -ParameterFilter {
                $body = $Body | ConvertFrom-Json
                $body.configuration.extension_list.scancategory -eq 'AllScans'
            } -Exactly 1 -Scope It
        }

        It 'Respects explicit ScanType parameter' {
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                return [PSCustomObject]@{ status = 'success' }
            }

            $result = Update-SEPMExceptionPolicy -PolicyName 'TestPolicy' -Extensions '.exe' -ScanType AutoProtect

            $result.status | Should -Be 'success'
            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -ParameterFilter {
                $body = $Body | ConvertFrom-Json
                $body.configuration.extension_list.scancategory -eq 'AutoProtect'
            } -Exactly 1 -Scope It
        }
    }

    Context 'Tamper' {
        BeforeEach {
            $script:fakeSession = New-TestSession -SkipCert
            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $script:fakeSession }
            Mock Get-SEPMPoliciesSummary -ModuleName PSSymantecSEPM {
                return New-DummyPolicySummary -PolicyName 'TestPolicy' -PolicyType 'exceptions'
            }
        }

        It 'Adds a tamper protection exception via PATCH' {
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                return [PSCustomObject]@{ status = 'success' }
            }

            $result = Update-SEPMExceptionPolicy -PolicyName 'TestPolicy' -TamperPath 'C:\test\file.exe'

            $result.status | Should -Be 'success'
            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Exactly 1 -Scope It
            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -ParameterFilter {
                $body = $Body | ConvertFrom-Json
                $t = $body.configuration.tamper_files[0]
                $t.path -eq 'C:\test\file.exe' -and
                $t.pathvariable -eq '[NONE]' -and
                $t.rulestate.source -eq 'PSSymantecSEPM'
            } -Exactly 1 -Scope It
        }

        It 'Sets deleted=true when Remove is specified' {
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                return [PSCustomObject]@{ status = 'success' }
            }

            $result = Update-SEPMExceptionPolicy -PolicyName 'TestPolicy' -TamperPath 'C:\test\file.exe' -Remove

            $result.status | Should -Be 'success'
            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -ParameterFilter {
                $body = $Body | ConvertFrom-Json
                $body.configuration.tamper_files[0].deleted -eq $true
            } -Exactly 1 -Scope It
        }

        It 'Rejects an invalid path without file extension' {
            { Update-SEPMExceptionPolicy -PolicyName 'TestPolicy' -TamperPath 'C:\test\folder' } |
                Should -Throw -ErrorId "ParameterArgumentValidationError,Update-SEPMExceptionPolicy"
        }

        It 'Defaults PathVariable to [NONE]' {
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                return [PSCustomObject]@{ status = 'success' }
            }

            $result = Update-SEPMExceptionPolicy -PolicyName 'TestPolicy' -TamperPath 'C:\test\file.exe'

            $result.status | Should -Be 'success'
            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -ParameterFilter {
                $body = $Body | ConvertFrom-Json
                $body.configuration.tamper_files[0].pathvariable -eq '[NONE]'
            } -Exactly 1 -Scope It
        }
    }

    Context 'MacFile' {
        BeforeEach {
            $script:fakeSession = New-TestSession -SkipCert
            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $script:fakeSession }
            Mock Get-SEPMPoliciesSummary -ModuleName PSSymantecSEPM {
                return New-DummyPolicySummary -PolicyName 'TestPolicy' -PolicyType 'exceptions'
            }
        }

        It 'Adds a Mac file exception via PATCH' {
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                return [PSCustomObject]@{ status = 'success' }
            }

            $result = Update-SEPMExceptionPolicy -PolicyName 'TestPolicy' -MacPath '/Applications/test.app'

            $result.status | Should -Be 'success'
            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Exactly 1 -Scope It
            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -ParameterFilter {
                $body = $Body | ConvertFrom-Json
                $f = $body.configuration.mac.files[0]
                $f.path -eq '/Applications/test.app' -and
                $f.pathvariable -eq '[NONE]' -and
                $f.rulestate.source -eq 'PSSymantecSEPM'
            } -Exactly 1 -Scope It
        }

        It 'Sets deleted=true when Remove is specified' {
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                return [PSCustomObject]@{ status = 'success' }
            }

            $result = Update-SEPMExceptionPolicy -PolicyName 'TestPolicy' -MacPath '/Applications/test.app' -Remove

            $result.status | Should -Be 'success'
            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -ParameterFilter {
                $body = $Body | ConvertFrom-Json
                $body.configuration.mac.files[0].deleted -eq $true
            } -Exactly 1 -Scope It
        }

        It 'Rejects an invalid Mac path' {
            { Update-SEPMExceptionPolicy -PolicyName 'TestPolicy' -MacPath 'C:\test\file.exe' } |
                Should -Throw -ErrorId "ParameterArgumentValidationError,Update-SEPMExceptionPolicy"
        }

        It 'Defaults PathVariable to [NONE]' {
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                return [PSCustomObject]@{ status = 'success' }
            }

            $result = Update-SEPMExceptionPolicy -PolicyName 'TestPolicy' -MacPath '/Applications/test.app'

            $result.status | Should -Be 'success'
            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -ParameterFilter {
                $body = $Body | ConvertFrom-Json
                $body.configuration.mac.files[0].pathvariable -eq '[NONE]'
            } -Exactly 1 -Scope It
        }
    }

    Context 'Default' {
        BeforeEach {
            $script:fakeSession = New-TestSession -SkipCert
            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $script:fakeSession }
            Mock Get-SEPMPoliciesSummary -ModuleName PSSymantecSEPM {
                return New-DummyPolicySummary -PolicyName 'TestPolicy' -PolicyType 'exceptions'
            }
        }

        It 'enables the policy via PATCH' {
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                return [PSCustomObject]@{ status = 'success' }
            }

            $result = Update-SEPMExceptionPolicy -PolicyName 'TestPolicy' -EnablePolicy

            $result.status | Should -Be 'success'
            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Exactly 1 -Scope It
            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -ParameterFilter {
                $body = $Body | ConvertFrom-Json
                $body.enabled -eq $true
            } -Exactly 1 -Scope It
        }

        It 'disables the policy via PATCH' {
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                return [PSCustomObject]@{ status = 'success' }
            }

            $result = Update-SEPMExceptionPolicy -PolicyName 'TestPolicy' -DisablePolicy

            $result.status | Should -Be 'success'
            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Exactly 1 -Scope It
            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -ParameterFilter {
                $body = $Body | ConvertFrom-Json
                $body.enabled -eq $false
            } -Exactly 1 -Scope It
        }

        It 'sets the policy description via PATCH' {
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                return [PSCustomObject]@{ status = 'success' }
            }

            $result = Update-SEPMExceptionPolicy -PolicyName 'TestPolicy' -PolicyDescription 'My new description'

            $result.status | Should -Be 'success'
            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Exactly 1 -Scope It
            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -ParameterFilter {
                $body = $Body | ConvertFrom-Json
                $body.desc -eq 'My new description'
            } -Exactly 1 -Scope It
        }

        It 'enable + description in same call' {
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                return [PSCustomObject]@{ status = 'success' }
            }

            $result = Update-SEPMExceptionPolicy -PolicyName 'TestPolicy' -EnablePolicy -PolicyDescription 'Enabled with desc'

            $result.status | Should -Be 'success'
            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Exactly 1 -Scope It
            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -ParameterFilter {
                $body = $Body | ConvertFrom-Json
                $body.enabled -eq $true -and
                $body.desc -eq 'Enabled with desc'
            } -Exactly 1 -Scope It
        }

        It 'enable + WindowsFile rule in same call' {
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                return [PSCustomObject]@{ status = 'success' }
            }

            $result = Update-SEPMExceptionPolicy -PolicyName 'TestPolicy' -Path 'C:\test\file.exe' -EnablePolicy

            $result.status | Should -Be 'success'
            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Exactly 1 -Scope It
            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -ParameterFilter {
                $body = $Body | ConvertFrom-Json
                $body.enabled -eq $true -and
                $body.configuration.files[0].path -eq 'C:\test\file.exe'
            } -Exactly 1 -Scope It
        }

        It 'throws when EnablePolicy and DisablePolicy are both specified' {
            { Update-SEPMExceptionPolicy -PolicyName 'TestPolicy' -EnablePolicy -DisablePolicy } |
                Should -Throw -ExpectedMessage '*EnablePolicy*DisablePolicy*'
        }
    }
}
