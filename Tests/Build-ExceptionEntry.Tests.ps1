[CmdletBinding()]
param()

Describe 'Build-ExceptionEntry' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context 'Unknown type' {
        It 'throws when type name is not in the schema' {
            InModuleScope PSSymantecSEPM {
                $schema = $script:_ExceptionSchema
                { Build-ExceptionEntry -Schema $schema -Type 'Bogus' -Properties @{} } |
                    Should -Throw -ExpectedMessage "Unknown exception entry type 'Bogus'.*"
            }
        }

        It 'throws with valid types listed in the error message' {
            InModuleScope PSSymantecSEPM {
                $schema = $script:_ExceptionSchema
                { Build-ExceptionEntry -Schema $schema -Type 'Nonexistent' -Properties @{} } |
                    Should -Throw -ExpectedMessage "*Valid types*"
            }
        }
    }

    Context 'Basic field copy — Files' {
        It 'copies string fields from properties into output hashtable' {
            InModuleScope PSSymantecSEPM {
                $schema = $script:_ExceptionSchema
                $props = @{
                    path         = 'C:\test\file.exe'
                    pathvariable = '[NONE]'
                    scancategory = 'GESC_ALL'
                }
                $result = Build-ExceptionEntry -Schema $schema -Type 'Files' -Properties $props
                $result | Should -Not -BeNullOrEmpty
                $result -is [hashtable] | Should -Be $true
                $result['path'] | Should -Be 'C:\test\file.exe'
                $result['pathvariable'] | Should -Be '[NONE]'
                $result['scancategory'] | Should -Be 'GESC_ALL'
            }
        }

        It 'copies bool fields from properties into output hashtable' {
            InModuleScope PSSymantecSEPM {
                $schema = $script:_ExceptionSchema
                $props = @{
                    path   = 'C:\test\file.exe'
                    sonar  = $true
                }
                $result = Build-ExceptionEntry -Schema $schema -Type 'Files' -Properties $props
                $result['sonar'] | Should -Be $true
            }
        }
    }

    Context 'Null and empty exclusion' {
        It 'excludes null values from output for optional fields' {
            InModuleScope PSSymantecSEPM {
                $schema = $script:_ExceptionSchema
                $props = @{
                    path         = 'C:\test\file.exe'
                    pathvariable = $null
                }
                $result = Build-ExceptionEntry -Schema $schema -Type 'Files' -Properties $props
                $result.ContainsKey('pathvariable') | Should -Be $false
                $result['path'] | Should -Be 'C:\test\file.exe'
            }
        }

        It 'excludes empty string values from output for optional fields' {
            InModuleScope PSSymantecSEPM {
                $schema = $script:_ExceptionSchema
                $props = @{
                    path         = 'C:\test\file.exe'
                    pathvariable = ''
                }
                $result = Build-ExceptionEntry -Schema $schema -Type 'Files' -Properties $props
                $result.ContainsKey('pathvariable') | Should -Be $false
            }
        }

        It 'null value for a required field still triggers the required-field error' {
            InModuleScope PSSymantecSEPM {
                $schema = $script:_ExceptionSchema
                { Build-ExceptionEntry -Schema $schema -Type 'Files' -Properties @{ path = $null } } |
                    Should -Throw -ExpectedMessage "Missing required field*"
            }
        }

        It 'empty string for a required field still triggers the required-field error' {
            InModuleScope PSSymantecSEPM {
                $schema = $script:_ExceptionSchema
                { Build-ExceptionEntry -Schema $schema -Type 'Files' -Properties @{ path = '' } } |
                    Should -Throw -ExpectedMessage "Missing required field*"
            }
        }
    }

    Context 'All 16 types' {
        It 'produces correct output for type Files' {
            InModuleScope PSSymantecSEPM {
                $schema = $script:_ExceptionSchema
                $result = Build-ExceptionEntry -Schema $schema -Type 'Files' -Properties @{ path = 'C:\test\file.exe'; sonar = $true; scancategory = 'GESC_ALL' }
                $result | Should -Not -BeNullOrEmpty
                $result -is [hashtable] | Should -Be $true
                $result.ContainsKey('rulestate') | Should -Be $true
                $result['path'] | Should -Be 'C:\test\file.exe'
                $result['sonar'] | Should -Be $true
            }
        }

        It 'produces correct output for type Directories' {
            InModuleScope PSSymantecSEPM {
                $schema = $script:_ExceptionSchema
                $result = Build-ExceptionEntry -Schema $schema -Type 'Directories' -Properties @{ pathvariable = '[NONE]'; directory = 'C:\Program Files'; recursive = $false }
                $result['pathvariable'] | Should -Be '[NONE]'
                $result['directory'] | Should -Be 'C:\Program Files'
            }
        }

        It 'produces correct output for type Extensions' {
            InModuleScope PSSymantecSEPM {
                $schema = $script:_ExceptionSchema
                $result = Build-ExceptionEntry -Schema $schema -Type 'Extensions' -Properties @{ extensions = @('exe', 'dll'); scancategory = 'GESC_AP' }
                $result['extensions'].Count | Should -Be 2
                $result['extensions'] -contains 'exe' | Should -Be $true
                $result['scancategory'] | Should -Be 'GESC_AP'
            }
        }

        It 'produces correct output for type Webdomains' {
            InModuleScope PSSymantecSEPM {
                $schema = $script:_ExceptionSchema
                $result = Build-ExceptionEntry -Schema $schema -Type 'Webdomains' -Properties @{ domain = 'example.com' }
                $result['domain'] | Should -Be 'example.com'
            }
        }

        It 'produces correct output for type Certificates' {
            InModuleScope PSSymantecSEPM {
                $schema = $script:_ExceptionSchema
                $result = Build-ExceptionEntry -Schema $schema -Type 'Certificates' -Properties @{ signature_fingerprint = @{ algorithm = 'SHA256'; value = '00:11:22' } }
                $result.ContainsKey('signature_fingerprint') | Should -Be $true
                $result.signature_fingerprint.algorithm | Should -Be 'SHA256'
                $result.signature_fingerprint.value | Should -Be '00:11:22'
            }
        }

        It 'produces correct output for type Applications' {
            InModuleScope PSSymantecSEPM {
                $schema = $script:_ExceptionSchema
                $result = Build-ExceptionEntry -Schema $schema -Type 'Applications' -Properties @{ processfile = @{ sha2 = 'abc'; name = 'app.exe' } }
                $result.ContainsKey('processfile') | Should -Be $true
                $result.processfile.sha2 | Should -Be 'abc'
            }
        }

        It 'produces correct output for type Denylistrules' {
            InModuleScope PSSymantecSEPM {
                $schema = $script:_ExceptionSchema
                $result = Build-ExceptionEntry -Schema $schema -Type 'Denylistrules' -Properties @{ processfile = @{ sha2 = 'abc' }; action = 'BLOCK' }
                $result['action'] | Should -Be 'BLOCK'
                $result.processfile.sha2 | Should -Be 'abc'
            }
        }

        It 'produces correct output for type AppsToMonitor' {
            InModuleScope PSSymantecSEPM {
                $schema = $script:_ExceptionSchema
                $result = Build-ExceptionEntry -Schema $schema -Type 'AppsToMonitor' -Properties @{ name = 'chrome.exe' }
                $result['name'] | Should -Be 'chrome.exe'
            }
        }

        It 'produces correct output for type MacFiles' {
            InModuleScope PSSymantecSEPM {
                $schema = $script:_ExceptionSchema
                $result = Build-ExceptionEntry -Schema $schema -Type 'MacFiles' -Properties @{ pathvariable = '[HOME]'; path = '/Applications/App.app' }
                $result['path'] | Should -Be '/Applications/App.app'
                $result['pathvariable'] | Should -Be '[HOME]'
            }
        }

        It 'produces correct output for type LinuxDirectories' {
            InModuleScope PSSymantecSEPM {
                $schema = $script:_ExceptionSchema
                $result = Build-ExceptionEntry -Schema $schema -Type 'LinuxDirectories' -Properties @{ pathvariable = '[NONE]'; directory = '/opt/app' }
                $result['pathvariable'] | Should -Be '[NONE]'
                $result['directory'] | Should -Be '/opt/app'
            }
        }

        It 'produces correct output for type LinuxExtensions' {
            InModuleScope PSSymantecSEPM {
                $schema = $script:_ExceptionSchema
                $result = Build-ExceptionEntry -Schema $schema -Type 'LinuxExtensions' -Properties @{ extensions = @('so', 'o') }
                $result['extensions'].Count | Should -Be 2
                $result['extensions'] -contains 'so' | Should -Be $true
            }
        }

        It 'produces correct output for type Knownrisks' {
            InModuleScope PSSymantecSEPM {
                $schema = $script:_ExceptionSchema
                $result = Build-ExceptionEntry -Schema $schema -Type 'Knownrisks' -Properties @{ threat = @{ id = 'THREAT-001'; name = 'Trojan.Generic' } }
                $result.ContainsKey('threat') | Should -Be $true
                $result.threat.id | Should -Be 'THREAT-001'
            }
        }

        It 'produces correct output for type TamperFiles' {
            InModuleScope PSSymantecSEPM {
                $schema = $script:_ExceptionSchema
                $result = Build-ExceptionEntry -Schema $schema -Type 'TamperFiles' -Properties @{ path = 'C:\test\file.exe'; sonar = $true; scancategory = 'GESC_ALL' }
                $result['path'] | Should -Be 'C:\test\file.exe'
                $result['sonar'] | Should -Be $true
            }
        }

        It 'produces correct output for type DnsAndHostApps' {
            InModuleScope PSSymantecSEPM {
                $schema = $script:_ExceptionSchema
                $result = Build-ExceptionEntry -Schema $schema -Type 'DnsAndHostApps' -Properties @{ processfile = @{ sha2 = 'abc' }; action = 'ALLOW' }
                $result['action'] | Should -Be 'ALLOW'
                $result.processfile.sha2 | Should -Be 'abc'
            }
        }

        It 'produces correct output for type DnsAndHostDeny' {
            InModuleScope PSSymantecSEPM {
                $schema = $script:_ExceptionSchema
                $result = Build-ExceptionEntry -Schema $schema -Type 'DnsAndHostDeny' -Properties @{ processfile = @{ sha2 = 'abc' }; action = 'BLOCK' }
                $result['action'] | Should -Be 'BLOCK'
                $result.processfile.sha2 | Should -Be 'abc'
            }
        }

        It 'produces correct output for type NonPEFiles' {
            InModuleScope PSSymantecSEPM {
                $schema = $script:_ExceptionSchema
                $result = Build-ExceptionEntry -Schema $schema -Type 'NonPEFiles' -Properties @{ file = @{ sha2 = 'file-hash'; name = 'bad.dll' }; actor = @{ sha2 = 'actor-hash'; name = 'loader.exe' } }
                $result.ContainsKey('file') | Should -Be $true
                $result.ContainsKey('actor') | Should -Be $true
                $result.file.name | Should -Be 'bad.dll'
                $result.actor.name | Should -Be 'loader.exe'
            }
        }

        It 'unknown type error lists all 16 valid types' {
            InModuleScope PSSymantecSEPM {
                $schema = $script:_ExceptionSchema
                $errorMsg = try {
                    Build-ExceptionEntry -Schema $schema -Type 'Invalid' -Properties @{} 2>&1
                } catch {
                    $_.Exception.Message
                }
                $errorMsg | Should -Match 'Files'
                $errorMsg | Should -Match 'Directories'
                $errorMsg | Should -Match 'NonPEFiles'
            }
        }
    }

    Context 'Sub-objects' {
        It 'builds processfile PSCustomObject from nested hashtable' {
            InModuleScope PSSymantecSEPM {
                $testSchema = @{
                    Applications = @{
                        ConfigPath = 'applications'
                        AddMethod  = 'Add'
                        Required   = @()
                        Fields     = @{
                            action = @{ type = 'string' }
                        }
                        SubObjects = @{
                            processfile = @{
                                Required = @('sha2')
                                Fields   = @{
                                    sha2        = @{ type = 'string' }
                                    md5         = @{ type = 'string' }
                                    name        = @{ type = 'string' }
                                    company     = @{ type = 'string' }
                                    size        = @{ type = 'int64' }
                                    description = @{ type = 'string' }
                                    directory   = @{ type = 'string' }
                                }
                            }
                        }
                    }
                }
                $props = @{
                    processfile = @{
                        sha2 = 'abcdef1234567890'
                        name = 'app.exe'
                    }
                }
                $result = Build-ExceptionEntry -Schema $testSchema -Type 'Applications' -Properties $props
                $result.ContainsKey('processfile') | Should -Be $true
                $result.processfile -is [PSCustomObject] | Should -Be $true
                $result.processfile.sha2 | Should -Be 'abcdef1234567890'
                $result.processfile.name | Should -Be 'app.exe'
            }
        }

        It 'validates required fields in sub-objects' {
            InModuleScope PSSymantecSEPM {
                $testSchema = @{
                    Applications = @{
                        ConfigPath = 'applications'
                        AddMethod  = 'Add'
                        Required   = @()
                        Fields     = @{
                            action = @{ type = 'string' }
                        }
                        SubObjects = @{
                            processfile = @{
                                Required = @('sha2')
                                Fields   = @{
                                    sha2 = @{ type = 'string' }
                                    name = @{ type = 'string' }
                                }
                            }
                        }
                    }
                }
                $props = @{
                    processfile = @{
                        name = 'app.exe'
                    }
                }
                { Build-ExceptionEntry -Schema $testSchema -Type 'Applications' -Properties $props } |
                    Should -Throw -ExpectedMessage "*Missing required field 'sha2' for sub-object 'processfile' in type 'Applications'.*"
            }
        }

        It 'excludes null values from sub-objects' {
            InModuleScope PSSymantecSEPM {
                $testSchema = @{
                    Applications = @{
                        ConfigPath = 'applications'
                        AddMethod  = 'Add'
                        Required   = @()
                        Fields     = @{ action = @{ type = 'string' } }
                        SubObjects = @{
                            processfile = @{
                                Required = @('sha2')
                                Fields   = @{
                                    sha2 = @{ type = 'string' }
                                    name = @{ type = 'string' }
                                    md5  = @{ type = 'string' }
                                }
                            }
                        }
                    }
                }
                $props = @{
                    processfile = @{
                        sha2 = 'abc'
                        name = $null
                    }
                }
                $result = Build-ExceptionEntry -Schema $testSchema -Type 'Applications' -Properties $props
                $result.processfile.sha2 | Should -Be 'abc'
                $result.processfile.PSObject.Properties.Name -contains 'name' | Should -Be $false
            }
        }

        It 'builds signature_fingerprint PSCustomObject from nested hashtable' {
            InModuleScope PSSymantecSEPM {
                $testSchema = @{
                    Certificates = @{
                        ConfigPath = 'certificates'
                        AddMethod  = 'Add'
                        Required   = @()
                        Fields     = @{
                            signature_company_name = @{ type = 'string' }
                            signature_issuer       = @{ type = 'string' }
                        }
                        SubObjects = @{
                            signature_fingerprint = @{
                                Required = @('algorithm', 'value')
                                Fields   = @{
                                    algorithm = @{ type = 'string' }
                                    value     = @{ type = 'string' }
                                }
                            }
                        }
                    }
                }
                $props = @{
                    signature_fingerprint = @{
                        algorithm = 'SHA256'
                        value     = '00:11:22:33'
                    }
                }
                $result = Build-ExceptionEntry -Schema $testSchema -Type 'Certificates' -Properties $props
                $result['signature_fingerprint'] -is [PSCustomObject] | Should -Be $true
                $result.signature_fingerprint.algorithm | Should -Be 'SHA256'
                $result.signature_fingerprint.value | Should -Be '00:11:22:33'
            }
        }

        It 'builds threat PSCustomObject from nested hashtable' {
            InModuleScope PSSymantecSEPM {
                $testSchema = @{
                    Knownrisks = @{
                        ConfigPath = 'knownrisks'
                        AddMethod  = 'Add'
                        Required   = @()
                        Fields     = @{
                            action = @{ type = 'string' }
                        }
                        SubObjects = @{
                            threat = @{
                                Required = @('id', 'name')
                                Fields   = @{
                                    id   = @{ type = 'string' }
                                    name = @{ type = 'string' }
                                }
                            }
                        }
                    }
                }
                $props = @{
                    threat = @{
                        id   = 'THREAT-001'
                        name = 'Trojan.Generic'
                    }
                }
                $result = Build-ExceptionEntry -Schema $testSchema -Type 'Knownrisks' -Properties $props
                $result.threat -is [PSCustomObject] | Should -Be $true
                $result.threat.id | Should -Be 'THREAT-001'
                $result.threat.name | Should -Be 'Trojan.Generic'
            }
        }

        It 'supports multiple sub-objects (file + actor for NonPEFiles)' {
            InModuleScope PSSymantecSEPM {
                $testSchema = @{
                    NonPEFiles = @{
                        ConfigPath = 'non_pe_rules'
                        AddMethod  = 'Add'
                        Required   = @()
                        Fields     = @{
                            action = @{ type = 'string' }
                        }
                        SubObjects = @{
                            file = @{
                                Required = @('sha2')
                                Fields   = @{
                                    sha2 = @{ type = 'string' }
                                    name = @{ type = 'string' }
                                }
                            }
                            actor = @{
                                Required = @('sha2')
                                Fields   = @{
                                    sha2 = @{ type = 'string' }
                                    name = @{ type = 'string' }
                                }
                            }
                        }
                    }
                }
                $props = @{
                    file  = @{ sha2 = 'file-hash'; name = 'bad.dll' }
                    actor = @{ sha2 = 'actor-hash'; name = 'loader.exe' }
                }
                $result = Build-ExceptionEntry -Schema $testSchema -Type 'NonPEFiles' -Properties $props
                $result.file -is [PSCustomObject] | Should -Be $true
                $result.file.name | Should -Be 'bad.dll'
                $result.actor -is [PSCustomObject] | Should -Be $true
                $result.actor.name | Should -Be 'loader.exe'
            }
        }
    }

    Context 'deleted flag' {
        It 'propagates deleted flag to output when present' {
            InModuleScope PSSymantecSEPM {
                $schema = $script:_ExceptionSchema
                $props = @{
                    path    = 'C:\test\file.exe'
                    deleted = $true
                }
                $result = Build-ExceptionEntry -Schema $schema -Type 'Files' -Properties $props
                $result['deleted'] | Should -Be $true
            }
        }

        It 'omits deleted when not present in properties' {
            InModuleScope PSSymantecSEPM {
                $schema = $script:_ExceptionSchema
                $props = @{
                    path = 'C:\test\file.exe'
                }
                $result = Build-ExceptionEntry -Schema $schema -Type 'Files' -Properties $props
                $result.ContainsKey('deleted') | Should -Be $false
            }
        }

        It 'propagates deleted=false when explicitly set' {
            InModuleScope PSSymantecSEPM {
                $schema = $script:_ExceptionSchema
                $props = @{
                    path    = 'C:\test\file.exe'
                    deleted = $false
                }
                $result = Build-ExceptionEntry -Schema $schema -Type 'Files' -Properties $props
                $result['deleted'] | Should -Be $false
            }
        }
    }

    Context 'rulestate' {
        It 'defaults to { source: "PSSymantecSEPM" } when not passed' {
            InModuleScope PSSymantecSEPM {
                $schema = $script:_ExceptionSchema
                $props = @{
                    path = 'C:\test\file.exe'
                }
                $result = Build-ExceptionEntry -Schema $schema -Type 'Files' -Properties $props
                $result.ContainsKey('rulestate') | Should -Be $true
                $result.rulestate -is [PSCustomObject] | Should -Be $true
                $result.rulestate.source | Should -Be 'PSSymantecSEPM'
                $result.rulestate.PSObject.Properties.Name -contains 'enabled' | Should -Be $false
            }
        }

        It 'can be fully overridden by passing rulestate in properties' {
            InModuleScope PSSymantecSEPM {
                $schema = $script:_ExceptionSchema
                $props = @{
                    path      = 'C:\test\file.exe'
                    rulestate = @{ source = 'CustomSource'; enabled = $false }
                }
                $result = Build-ExceptionEntry -Schema $schema -Type 'Files' -Properties $props
                $result.rulestate.source | Should -Be 'CustomSource'
                $result.rulestate.enabled | Should -Be $false
            }
        }

        It 'merges rulestate_enabled into default rulestate' {
            InModuleScope PSSymantecSEPM {
                $schema = $script:_ExceptionSchema
                $props = @{
                    path              = 'C:\test\file.exe'
                    rulestate_enabled = $true
                }
                $result = Build-ExceptionEntry -Schema $schema -Type 'Files' -Properties $props
                $result.rulestate.source | Should -Be 'PSSymantecSEPM'
                $result.rulestate.enabled | Should -Be $true
            }
        }

        It 'rulestate override takes precedence over rulestate_enabled' {
            InModuleScope PSSymantecSEPM {
                $schema = $script:_ExceptionSchema
                $props = @{
                    path              = 'C:\test\file.exe'
                    rulestate         = @{ source = 'Override'; enabled = $false }
                    rulestate_enabled = $true
                }
                $result = Build-ExceptionEntry -Schema $schema -Type 'Files' -Properties $props
                $result.rulestate.source | Should -Be 'Override'
                $result.rulestate.enabled | Should -Be $false
            }
        }
    }

    Context 'Enum validation' {
        It 'throws when an enum field has an invalid value' {
            InModuleScope PSSymantecSEPM {
                $schema = $script:_ExceptionSchema
                $props = @{
                    path         = 'C:\test\file.exe'
                    scancategory = 'BOGUS_VALUE'
                }
                { Build-ExceptionEntry -Schema $schema -Type 'Files' -Properties $props } |
                    Should -Throw -ExpectedMessage "*Invalid value 'BOGUS_VALUE' for field 'scancategory'*"
            }
        }

        It 'throws listing valid values for invalid enum' {
            InModuleScope PSSymantecSEPM {
                $schema = $script:_ExceptionSchema
                $props = @{
                    path         = 'C:\test\file.exe'
                    scancategory = 'INVALID'
                }
                { Build-ExceptionEntry -Schema $schema -Type 'Files' -Properties $props } |
                    Should -Throw -ExpectedMessage "*Valid values: GESC_AP, GESC_MANUAL, GESC_ALL*"
            }
        }

        It 'accepts valid enum values' {
            InModuleScope PSSymantecSEPM {
                $schema = $script:_ExceptionSchema
                $props = @{
                    path         = 'C:\test\file.exe'
                    scancategory = 'GESC_AP'
                }
                $result = Build-ExceptionEntry -Schema $schema -Type 'Files' -Properties $props
                $result['scancategory'] | Should -Be 'GESC_AP'
            }
        }
    }

    Context 'Required field validation' {
        It 'throws when a required field is missing' {
            InModuleScope PSSymantecSEPM {
                $schema = $script:_ExceptionSchema
                { Build-ExceptionEntry -Schema $schema -Type 'Files' -Properties @{ sonar = $true } } |
                    Should -Throw -ExpectedMessage "Missing required field 'path' for type 'Files'.*"
            }
        }

        It 'throws listing all missing required fields' {
            InModuleScope PSSymantecSEPM {
                $schema = $script:_ExceptionSchema
                # We'll use a type with multiple required fields — add Directories to schema
                # with pathvariable and directory both required
                $testSchema = @{
                    Directories = @{
                        ConfigPath = 'directories'
                        AddMethod  = 'Add'
                        Required   = @('pathvariable', 'directory')
                        Fields     = @{
                            pathvariable = @{ type = 'string' }
                            directory    = @{ type = 'string' }
                            recursive    = @{ type = 'bool' }
                        }
                    }
                }
                { Build-ExceptionEntry -Schema $testSchema -Type 'Directories' -Properties @{ recursive = $true } } |
                    Should -Throw -ExpectedMessage "*pathvariable*directory*"
            }
        }
    }
}
