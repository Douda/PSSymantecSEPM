[CmdletBinding()]
param()

Describe 'Optimize-SEPMObject' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context 'Null property stripping' {
        It 'strips null properties from a PSCustomObject' {
            InModuleScope PSSymantecSEPM {
                $input = [PSCustomObject]@{
                    name    = 'test'
                    empty   = $null
                    value   = 'keep'
                }
                $result = Optimize-SEPMObject -InputObject $input
                $result.PSObject.Properties.Name -contains 'name' | Should -Be $true
                $result.PSObject.Properties.Name -contains 'value' | Should -Be $true
                $result.PSObject.Properties.Name -contains 'empty' | Should -Be $false
            }
        }
    }

    Context 'Empty array stripping' {
        It 'strips empty arrays' {
            InModuleScope PSSymantecSEPM {
                $input = [PSCustomObject]@{
                    name   = 'test'
                    items  = @()
                    value  = 'keep'
                }
                $result = Optimize-SEPMObject -InputObject $input
                $result.PSObject.Properties.Name -contains 'name' | Should -Be $true
                $result.PSObject.Properties.Name -contains 'value' | Should -Be $true
                $result.PSObject.Properties.Name -contains 'items' | Should -Be $false
            }
        }

        It 'keeps non-empty arrays' {
            InModuleScope PSSymantecSEPM {
                $input = [PSCustomObject]@{
                    name   = 'test'
                    items  = @('a', 'b')
                }
                $result = Optimize-SEPMObject -InputObject $input
                $result.PSObject.Properties.Name -contains 'items' | Should -Be $true
                $result.items.Count | Should -Be 2
            }
        }
    }

    Context 'Empty IDictionary stripping' {
        It 'strips empty IDictionary' {
            InModuleScope PSSymantecSEPM {
                $input = [PSCustomObject]@{
                    name  = 'test'
                    empty = @{}
                    value = 'keep'
                }
                $result = Optimize-SEPMObject -InputObject $input
                $result.PSObject.Properties.Name -contains 'name' | Should -Be $true
                $result.PSObject.Properties.Name -contains 'value' | Should -Be $true
                $result.PSObject.Properties.Name -contains 'empty' | Should -Be $false
            }
        }

        It 'keeps non-empty IDictionary' {
            InModuleScope PSSymantecSEPM {
                $input = [PSCustomObject]@{
                    name  = 'test'
                    dict  = @{ key = 'val' }
                }
                $result = Optimize-SEPMObject -InputObject $input
                $result.PSObject.Properties.Name -contains 'dict' | Should -Be $true
                $result.dict.key | Should -Be 'val'
            }
        }
    }

    Context 'SEPM domain rules' {
        It 'removes mac when mac.files is empty' {
            InModuleScope PSSymantecSEPM {
                $input = [PSCustomObject]@{
                    name   = 'test'
                    mac    = [PSCustomObject]@{ files = @() }
                    value  = 'keep'
                }
                $result = Optimize-SEPMObject -InputObject $input
                $result.PSObject.Properties.Name -contains 'name' | Should -Be $true
                $result.PSObject.Properties.Name -contains 'value' | Should -Be $true
                $result.PSObject.Properties.Name -contains 'mac' | Should -Be $false
            }
        }

        It 'keeps mac when mac.files is non-empty' {
            InModuleScope PSSymantecSEPM {
                $input = [PSCustomObject]@{
                    name = 'test'
                    mac  = [PSCustomObject]@{ files = @([PSCustomObject]@{ path = '/tmp/a' }) }
                }
                $result = Optimize-SEPMObject -InputObject $input
                $result.PSObject.Properties.Name -contains 'mac' | Should -Be $true
                $result.mac.files.Count | Should -Be 1
            }
        }

        It 'removes linux when both directories and extension_list.extensions are empty' {
            InModuleScope PSSymantecSEPM {
                $input = [PSCustomObject]@{
                    name  = 'test'
                    linux = [PSCustomObject]@{
                        directories    = @()
                        extension_list = [PSCustomObject]@{ extensions = @() }
                    }
                }
                $result = Optimize-SEPMObject -InputObject $input
                $result.PSObject.Properties.Name -contains 'name' | Should -Be $true
                $result.PSObject.Properties.Name -contains 'linux' | Should -Be $false
            }
        }

        It 'keeps linux when directories are non-empty' {
            InModuleScope PSSymantecSEPM {
                $input = [PSCustomObject]@{
                    name  = 'test'
                    linux = [PSCustomObject]@{
                        directories    = @([PSCustomObject]@{ path = '/opt/app' })
                        extension_list = [PSCustomObject]@{ extensions = @() }
                    }
                }
                $result = Optimize-SEPMObject -InputObject $input
                $result.PSObject.Properties.Name -contains 'linux' | Should -Be $true
            }
        }

        It 'keeps linux when extension_list.extensions are non-empty' {
            InModuleScope PSSymantecSEPM {
                $input = [PSCustomObject]@{
                    name  = 'test'
                    linux = [PSCustomObject]@{
                        directories    = @()
                        extension_list = [PSCustomObject]@{ extensions = @('exe', 'dll') }
                    }
                }
                $result = Optimize-SEPMObject -InputObject $input
                $result.PSObject.Properties.Name -contains 'linux' | Should -Be $true
            }
        }

        It 'removes extension_list when extensions is empty' {
            InModuleScope PSSymantecSEPM {
                $input = [PSCustomObject]@{
                    name           = 'test'
                    extension_list = [PSCustomObject]@{ extensions = @() }
                    value          = 'keep'
                }
                $result = Optimize-SEPMObject -InputObject $input
                $result.PSObject.Properties.Name -contains 'name' | Should -Be $true
                $result.PSObject.Properties.Name -contains 'value' | Should -Be $true
                $result.PSObject.Properties.Name -contains 'extension_list' | Should -Be $false
            }
        }

        It 'keeps extension_list when extensions is non-empty' {
            InModuleScope PSSymantecSEPM {
                $input = [PSCustomObject]@{
                    name           = 'test'
                    extension_list = [PSCustomObject]@{ extensions = @('exe', 'dll') }
                }
                $result = Optimize-SEPMObject -InputObject $input
                $result.PSObject.Properties.Name -contains 'extension_list' | Should -Be $true
                $result.extension_list.extensions.Count | Should -Be 2
            }
        }

        It 'removes lockedoptions when it has zero NoteProperties' {
            InModuleScope PSSymantecSEPM {
                $input = [PSCustomObject]@{
                    name          = 'test'
                    lockedoptions = [PSCustomObject]@{}
                    value         = 'keep'
                }
                $result = Optimize-SEPMObject -InputObject $input
                $result.PSObject.Properties.Name -contains 'name' | Should -Be $true
                $result.PSObject.Properties.Name -contains 'value' | Should -Be $true
                $result.PSObject.Properties.Name -contains 'lockedoptions' | Should -Be $false
            }
        }

        It 'keeps lockedoptions when it has NoteProperties' {
            InModuleScope PSSymantecSEPM {
                $input = [PSCustomObject]@{
                    name          = 'test'
                    lockedoptions = [PSCustomObject]@{ file = $true }
                }
                $result = Optimize-SEPMObject -InputObject $input
                $result.PSObject.Properties.Name -contains 'lockedoptions' | Should -Be $true
                $result.lockedoptions.file | Should -Be $true
            }
        }
    }

    Context 'Class instance cloning' {
        It 'clones a SEPMPolicyExceptionsStructure class instance correctly (PS 7+ path)' {
            InModuleScope PSSymantecSEPM {
                $policy = [SEPMPolicyExceptionsStructure]::new()
                $policy.name = 'TestPolicy'
                $policy.desc = 'Test Description'
                $policy.lockedoptions.file = $true
                $policy.lockedoptions.extension = $false
                $policy.enabled = $true

                $result = Optimize-SEPMObject -InputObject $policy

                $result | Should -Not -BeNullOrEmpty
                $result -is [PSCustomObject] | Should -Be $true
                $result.name | Should -Be 'TestPolicy'
                $result.desc | Should -Be 'Test Description'
                $result.enabled | Should -Be $true
                # Class instance cloned to PSCustomObject (no type wrappers)
                $result.GetType().FullName | Should -Be 'System.Management.Automation.PSCustomObject'
                # lockedoptions survives because it has entries
                $result.PSObject.Properties.Name -contains 'lockedoptions' | Should -Be $true
                $result.lockedoptions.file | Should -Be $true
            }
        }

        It 'clones a SEPMPolicyExceptionsStructure class instance correctly (PS 5.1 path)' {
            InModuleScope PSSymantecSEPM {
                $orig = $PSVersionTable
                try {
                    Set-Variable -Name PSVersionTable -Scope Script -Value ([PSCustomObject]@{ PSVersion = [PSCustomObject]@{ Major = 5 } })
                    $policy = [SEPMPolicyExceptionsStructure]::new()
                    $policy.name = 'TestPolicy'
                    $policy.desc = 'Test Description'
                    $policy.lockedoptions.file = $true
                    $policy.lockedoptions.extension = $false
                    $policy.enabled = $true

                    $result = Optimize-SEPMObject -InputObject $policy

                    $result | Should -Not -BeNullOrEmpty
                    $result -is [PSCustomObject] | Should -Be $true
                    $result.name | Should -Be 'TestPolicy'
                    $result.desc | Should -Be 'Test Description'
                    $result.enabled | Should -Be $true
                    $result.GetType().FullName | Should -Be 'System.Management.Automation.PSCustomObject'
                    $result.PSObject.Properties.Name -contains 'lockedoptions' | Should -Be $true
                    $result.lockedoptions.file | Should -Be $true
                } finally {
                    Set-Variable -Name PSVersionTable -Scope Script -Value $orig
                }
            }
        }
    }

    Context 'Roundtrip from class methods' {
        It 'object built with CreateFilesHashTable and AddConfigurationFilesExceptions survives roundtrip' {
            InModuleScope PSSymantecSEPM {
                $policy = [SEPMPolicyExceptionsStructure]::new()
                $policy.name = 'TestPolicy'

                $fileHash = $policy.CreateFilesHashTable(
                    $false,   # sonar
                    $false,   # deleted
                    $true,    # rulestate_enabled
                    'PSSymantecSEPM',
                    'AllScans',
                    '[NONE]',
                    'C:\test\file.exe',
                    $false,   # applicationcontrol
                    $true,    # securityrisk
                    $false    # recursive
                )
                $policy.AddConfigurationFilesExceptions($fileHash)

                $result = Optimize-SEPMObject -InputObject $policy

                $result | Should -Not -BeNullOrEmpty
                $result.name | Should -Be 'TestPolicy'
                $result.configuration | Should -Not -BeNullOrEmpty
                $result.configuration.files | Should -Not -BeNullOrEmpty
                $result.configuration.files.Count | Should -Be 1
                $result.configuration.files[0].path | Should -Be 'C:\test\file.exe'
                $result.configuration.files[0].rulestate.enabled | Should -Be $true
            }
        }
    }
}
