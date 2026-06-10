[CmdletBinding()]
param()

Describe 'Get-SEPMExceptionPolicy' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context 'Full policy retrieval (default)' {
        BeforeAll {
            $script:fakeSession = New-TestSession -SkipCert

            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $script:fakeSession }
            Mock Get-SEPMPoliciesSummary -ModuleName PSSymantecSEPM {
                return New-DummyPolicySummary -PolicyName 'Test Exceptions' -PolicyType 'exceptions'
            }
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                return @{
                    sources          = @{}
                    configuration    = @{
                        files            = @(
                            @{ SONAR = $true; rulestate = @{ enabled = $true; source = 'PSSymantecSEPM' }; scancategory = 'AutoProtect'; pathvariable = '[NONE]'; path = 'C:\Temp\File5.exe'; applicationcontrol = $false; securityrisk = $false; recursive = $false }
                        )
                        directories      = @(
                            @{ rulestate = @{ enabled = $true }; scancategory = 'AutoProtect'; scantype = 'SecurityRisk'; pathvariable = '[NONE]'; directory = 'C:\Temp\SecurityRiskAP\'; recursive = $false }
                        )
                        webdomains       = @(
                            @{ rulestate = @{ enabled = $true; source = 'PSSymantecSEPM' }; domain = 'HTTPS://test.com' }
                        )
                        extension_list   = @(
                            @{ rulestate = @{ enabled = $true }; scancategory = 'AllScans'; extensions = @('.tmp') }
                            @{ rulestate = @{ enabled = $true }; scancategory = 'AllScans'; extensions = @('.log') }
                        )
                        tamper_files     = @(
                            @{ rulestate = @{ enabled = $true; source = 'PSSymantecSEPM' }; path = 'C:\Program Files\MyApp\app.exe'; pathvariable = '[NONE]' }
                        )
                        mac              = @{
                            files = @(
                                @{ SONAR = $false; rulestate = @{ enabled = $true }; path = '/Applications/test/SONAR'; pathvariable = '[NONE]' }
                            )
                        }
                        linux            = @{
                            directories = @(
                                @{ rulestate = @{ enabled = $true }; directory = '/home/user1/ExcludedFolder'; recursive = $true }
                            )
                            extension_list = @(
                                @{ extensions = @('.dk') }
                            )
                        }
                    }
                    lockedoptions    = @{
                        knownrisk  = $true
                        extension  = $true
                        file       = $true
                        domain     = $true
                    }
                    enabled          = $true
                    desc             = 'Test policy description'
                    name             = 'Test Exceptions'
                    lastmodifiedtime = 1646398353107
                }
            }
        }

        It 'returns the full exception policy with correct top-level properties' {
            $result = Get-SEPMExceptionPolicy -PolicyName 'Test Exceptions'

            $result | Should -Not -BeNullOrEmpty
            $result.name | Should -Be 'Test Exceptions'
            $result.enabled | Should -Be $true
            $result.desc | Should -Be 'Test policy description'
            $result.lastmodifiedtime | Should -Be 1646398353107
        }

        It 'adds SEPM.ExceptionPolicy type name to the output' {
            $result = Get-SEPMExceptionPolicy -PolicyName 'Test Exceptions'

            $result.PSObject.TypeNames[0] | Should -Be 'SEPM.ExceptionPolicy'
        }

        It 'returns nested configuration with all exception categories' {
            $result = Get-SEPMExceptionPolicy -PolicyName 'Test Exceptions'

            $config = $result.configuration
            $config | Should -Not -Be $null
            $config.files | Should -Not -Be $null
            $config.files.Count | Should -Be 1
            $config.directories | Should -Not -Be $null
            $config.directories.Count | Should -Be 1
            $config.webdomains | Should -Not -Be $null
            $config.webdomains.Count | Should -Be 1
            $config.extension_list | Should -Not -Be $null
            $config.tamper_files | Should -Not -Be $null
            $config.tamper_files.Count | Should -Be 1
        }

        It 'returns Mac and Linux sections in configuration' {
            $result = Get-SEPMExceptionPolicy -PolicyName 'Test Exceptions'

            $config = $result.configuration
            $config.mac | Should -Not -Be $null
            $config.mac.files | Should -Not -Be $null
            $config.mac.files.Count | Should -Be 1
            $config.mac.files[0].path | Should -Be '/Applications/test/SONAR'
            $config.linux | Should -Not -Be $null
            $config.linux.directories | Should -Not -Be $null
            $config.linux.extension_list | Should -Not -Be $null
        }

        It 'returns locked options with expected keys' {
            $result = Get-SEPMExceptionPolicy -PolicyName 'Test Exceptions'

            $result.lockedoptions | Should -Not -Be $null
            $result.lockedoptions.knownrisk | Should -Be $true
            $result.lockedoptions.extension | Should -Be $true
        }

        It 'triggers the lastModifiedTimeDate ScriptProperty' {
            $result = Get-SEPMExceptionPolicy -PolicyName 'Test Exceptions'

            $result.lastModifiedTimeDate | Should -Not -Be $null
        }
    }

    Context 'Listing specific exception categories' {
        BeforeAll {
            $script:fakeSession = New-TestSession -SkipCert

            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $script:fakeSession }
            Mock Get-SEPMPoliciesSummary -ModuleName PSSymantecSEPM {
                return New-DummyPolicySummary -PolicyName 'Test Exceptions' -PolicyType 'exceptions'
            }
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                return @{
                    sources          = @{}
                    configuration    = @{
                        files            = @(
                            @{ SONAR = $true; rulestate = @{ enabled = $true; source = 'PSSymantecSEPM' }; scancategory = 'AutoProtect'; pathvariable = '[NONE]'; path = 'C:\Temp\File5.exe'; applicationcontrol = $false; securityrisk = $false; recursive = $false }
                            @{ SONAR = $false; rulestate = @{ enabled = $true }; scancategory = 'AllScans'; pathvariable = '[NONE]'; path = 'C:\Temp\File.exe'; applicationcontrol = $true; securityrisk = $true; recursive = $false }
                        )
                        directories      = @(
                            @{ rulestate = @{ enabled = $true }; scancategory = 'AutoProtect'; scantype = 'SecurityRisk'; pathvariable = '[NONE]'; directory = 'C:\Temp\Dir1\'; recursive = $false }
                            @{ rulestate = @{ enabled = $true }; scancategory = 'AllScans'; scantype = 'All'; pathvariable = '[NONE]'; directory = 'C:\Temp\Dir2\'; recursive = $true }
                        )
                        webdomains       = @(
                            @{ rulestate = @{ enabled = $true; source = 'PSSymantecSEPM' }; domain = 'HTTPS://test.com' }
                            @{ rulestate = @{ enabled = $true }; domain = 'HTTP://test.com' }
                        )
                        extension_list   = @(
                            @{ rulestate = @{ enabled = $true }; scancategory = 'AllScans'; extensions = @('.tmp') }
                            @{ rulestate = @{ enabled = $true }; scancategory = 'AllScans'; extensions = @('.log') }
                        )
                        tamper_files     = @(
                            @{ rulestate = @{ enabled = $true; source = 'PSSymantecSEPM' }; path = 'C:\Program Files\App\app.exe'; pathvariable = '[NONE]' }
                        )
                        mac              = @{
                            files = @(
                                @{ SONAR = $false; rulestate = @{ enabled = $true }; path = '/Applications/test/SONAR'; pathvariable = '[NONE]' }
                            )
                        }
                        linux            = @{
                            directories     = @(
                                @{ rulestate = @{ enabled = $true }; directory = '/home/user1/ExcludedFolder'; recursive = $true }
                            )
                            extension_list  = @(
                                @{ extensions = @('.dk') }
                            )
                        }
                    }
                    lockedoptions    = @{}
                    enabled          = $true
                    desc             = ''
                    name             = 'Test Exceptions'
                    lastmodifiedtime = 1646398353107
                }
            }
        }

        It 'lists files with Platform Windows and Mac' {
            $result = Get-SEPMExceptionPolicy -PolicyName 'Test Exceptions' -List files

            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -Be 3
            @($result | Where-Object { $_.Platform -eq 'Windows' }).Count | Should -Be 2
            @($result | Where-Object { $_.Platform -eq 'Mac' }).Count | Should -Be 1
            ($result | Where-Object { $_.Platform -eq 'Windows' })[0].path | Should -Be 'C:\Temp\File5.exe'
            ($result | Where-Object { $_.Platform -eq 'Mac' })[0].path | Should -Be '/Applications/test/SONAR'
        }

        It 'lists directories with Platform Windows and Linux' {
            $result = Get-SEPMExceptionPolicy -PolicyName 'Test Exceptions' -List directories

            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -Be 3
            @($result | Where-Object { $_.Platform -eq 'Windows' }).Count | Should -Be 2
            @($result | Where-Object { $_.Platform -eq 'Linux' }).Count | Should -Be 1
        }

        It 'lists webdomains as flattened objects' {
            $result = Get-SEPMExceptionPolicy -PolicyName 'Test Exceptions' -List webdomains

            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -Be 2
            $result[0].domain | Should -Be 'HTTPS://test.com'
        }

        It 'lists extensions with Platform Windows and Linux' {
            $result = Get-SEPMExceptionPolicy -PolicyName 'Test Exceptions' -List extensions

            $result | Should -Not -BeNullOrEmpty
            @($result | Where-Object { $_.Platform -eq 'Windows' }).Count | Should -Be 2
            @($result | Where-Object { $_.Platform -eq 'Linux' }).Count | Should -Be 1
        }

        It 'lists tamper files as flattened objects' {
            $result = Get-SEPMExceptionPolicy -PolicyName 'Test Exceptions' -List tamper

            $result | Should -Not -BeNullOrEmpty
            @($result).Count | Should -Be 1
            $result[0].path | Should -Be 'C:\Program Files\App\app.exe'
        }
    }

    Context 'Error handling' {
        BeforeAll {
            $script:fakeSession = New-TestSession -SkipCert

            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $script:fakeSession }
            Mock Get-SEPMPoliciesSummary -ModuleName PSSymantecSEPM {
                return New-DummyPolicySummary -PolicyName 'Not Exceptions' -PolicyType 'av'
            }
        }

        It 'throws a terminating error when policy type is not exceptions' {
            { Get-SEPMExceptionPolicy -PolicyName 'Not Exceptions' } | Should -Throw
        }

        It 'error message mentions EXCEPTIONS policy type mismatch' {
            { Get-SEPMExceptionPolicy -PolicyName 'Not Exceptions' } | Should -Throw -ExpectedMessage '*policy type is not of type EXCEPTIONS*'
        }
    }

    Context 'Pipeline support' {
        BeforeAll {
            $script:fakeSession = New-TestSession -SkipCert

            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $script:fakeSession }
            Mock Get-SEPMPoliciesSummary -ModuleName PSSymantecSEPM {
                return New-DummyPolicySummary -PolicyName 'Pipeline Policy' -PolicyType 'exceptions'
            }
            Mock Invoke-SepmApi -ModuleName PSSymantecSEPM {
                return @{
                    sources          = @{}
                    configuration    = @{
                        files = @()
                        directories = @()
                        webdomains = @()
                        extension_list = @()
                        tamper_files = @()
                        mac = @{ files = @() }
                        linux = @{ directories = @(); extension_list = @() }
                    }
                    lockedoptions    = @{}
                    enabled          = $true
                    desc             = ''
                    name             = 'Pipeline Policy'
                    lastmodifiedtime = 1646398353107
                }
            }
        }

        It 'accepts PolicyName from the pipeline by value' {
            $result = 'Pipeline Policy' | Get-SEPMExceptionPolicy

            $result | Should -Not -BeNullOrEmpty
            $result.name | Should -Be 'Pipeline Policy'
            $result.PSObject.TypeNames[0] | Should -Be 'SEPM.ExceptionPolicy'
        }
    }
}
