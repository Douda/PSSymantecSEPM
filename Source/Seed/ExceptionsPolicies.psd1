@{
    Policies = @(
        @{
            Name        = 'Standard Workstation Exceptions'
            Description = 'Mixed file, folder, and extension exceptions for standard workstations'
            Enabled     = $true
            Configuration = @{
                files = @(
                    @{
                        path              = 'C:\Program Files\LegacyApp\legacy.exe'
                        pathvariable      = '[NONE]'
                        scancategory      = 'AllScans'
                        securityrisk      = $true
                        sonar             = $true
                        applicationcontrol = $true
                    }
                    @{
                        path              = 'C:\ERP\bin\erp-processor.exe'
                        pathvariable      = '[NONE]'
                        securityrisk      = $true
                    }
                    @{
                        path              = 'C:\BackupAgent\bagent.exe'
                        pathvariable      = '[PROGRAM_FILES]'
                        securityrisk      = $true
                        sonar             = $true
                    }
                )
                directories = @(
                    @{
                        directory         = 'C:\ERP\logs\'
                        pathvariable      = '[NONE]'
                        scantype          = 'All'
                        recursive         = $true
                    }
                    @{
                        directory         = 'C:\ProgramData\Cache\'
                        pathvariable      = '[NONE]'
                        scantype          = 'SecurityRisk'
                        scancategory      = 'AutoProtect'
                        recursive         = $true
                    }
                )
                extension_list = @{
                    extensions         = @('.erplog', '.cachelog')
                    scantype           = 'AllScans'
                }
            }
        }
        @{
            Name        = 'Server Exceptions'
            Description = 'Tamper protection bypasses only — no file or folder exceptions'
            Enabled     = $true
            Configuration = @{
                tamper_files = @(
                    @{
                        path              = 'C:\Program Files\BackupService\backupd.exe'
                        pathvariable      = '[NONE]'
                    }
                    @{
                        path              = 'C:\Program Files\MonitoringAgent\monagent.exe'
                        pathvariable      = '[PROGRAM_FILES]'
                    }
                )
            }
        }
        @{
            Name        = 'Developer Exceptions'
            Description = 'Broad folder exceptions with all scan categories for developer workstations'
            Enabled     = $true
            Configuration = @{
                directories = @(
                    @{
                        directory         = 'C:\Dev\Projects\'
                        pathvariable      = '[NONE]'
                        scantype          = 'All'
                        recursive         = $true
                    }
                    @{
                        directory         = 'C:\Builds\Output\'
                        pathvariable      = '[NONE]'
                        scantype          = 'All'
                        recursive         = $true
                    }
                )
                files = @(
                    @{
                        path              = 'C:\Tools\Compiler\customcc.exe'
                        pathvariable      = '[NONE]'
                        securityrisk      = $true
                        sonar             = $true
                        applicationcontrol = $true
                    }
                )
                extension_list = @{
                    extensions         = @('.obj', '.pdb', '.ilk')
                    scantype           = 'AllScans'
                }
            }
        }
        @{
            Name        = 'Emergency Disabled'
            Description = 'Same rules as Standard Workstation Exceptions but disabled for emergency use'
            Enabled     = $false
            Configuration = @{
                files = @(
                    @{
                        path              = 'C:\Program Files\LegacyApp\legacy.exe'
                        pathvariable      = '[NONE]'
                        scancategory      = 'AllScans'
                        securityrisk      = $true
                        sonar             = $true
                        applicationcontrol = $true
                    }
                    @{
                        path              = 'C:\ERP\bin\erp-processor.exe'
                        pathvariable      = '[NONE]'
                        securityrisk      = $true
                    }
                    @{
                        path              = 'C:\BackupAgent\bagent.exe'
                        pathvariable      = '[PROGRAM_FILES]'
                        securityrisk      = $true
                        sonar             = $true
                    }
                )
                directories = @(
                    @{
                        directory         = 'C:\ERP\logs\'
                        pathvariable      = '[NONE]'
                        scantype          = 'All'
                        recursive         = $true
                    }
                    @{
                        directory         = 'C:\ProgramData\Cache\'
                        pathvariable      = '[NONE]'
                        scantype          = 'SecurityRisk'
                        scancategory      = 'AutoProtect'
                        recursive         = $true
                    }
                )
                extension_list = @{
                    extensions         = @('.erplog', '.cachelog')
                    scantype           = 'AllScans'
                }
            }
        }
    )
}
