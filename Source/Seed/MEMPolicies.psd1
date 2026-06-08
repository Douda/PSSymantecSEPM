@{
    Policies = @(
        @{
            Name        = 'Standard MEM'
            Description = 'Basic Memory Exploit Mitigation with Java protection, no custom rules or technique overrides'
            Enabled     = $true
            Configuration = @{
                enabled                 = $true
                enableadvanced          = $false
                enablejavaprotection    = $true
                disabledefaultrules     = $false
                globalauditmodeoverride = $false
                customrules             = $null
                globaltechniqueoverrides = $null
            }
        }
        @{
            Name        = 'Advanced MEM'
            Description = 'Basic+Advanced MEM with Java protection, BLOCK global technique overrides, and custom application paths'
            Enabled     = $true
            Configuration = @{
                enabled                 = $true
                enableadvanced          = $true
                enablejavaprotection    = $true
                disabledefaultrules     = $false
                globalauditmodeoverride = $false
                globaltechniqueoverrides = @(
                    @{
                        id         = 61001
                        name       = 'Heap Spray'
                        action     = 'BLOCK'
                        log_action = 1
                        state      = 1
                    }
                    @{
                        id         = 61002
                        name       = 'Stack Pivot'
                        action     = 'BLOCK'
                        log_action = 1
                        state      = 1
                    }
                    @{
                        id         = 61003
                        name       = 'ROP Gadget'
                        action     = 'BLOCK'
                        log_action = 1
                        state      = 1
                    }
                    @{
                        id         = 61004
                        name       = 'SEH Overwrite'
                        action     = 'BLOCK'
                        log_action = 1
                        state      = 1
                    }
                )
                customrules = @(
                    @{
                        path = 'C:\Program Files\CustomApp\app.exe'
                    }
                    @{
                        path = 'C:\Program Files\LegacySystem\legacy.exe'
                    }
                )
            }
        }
        @{
            Name        = 'Java-Only MEM'
            Description = 'Java Security Manager Protection only — basic and advanced MEM disabled'
            Enabled     = $true
            Configuration = @{
                enabled                 = $false
                enableadvanced          = $false
                enablejavaprotection    = $true
                disabledefaultrules     = $false
                globalauditmodeoverride = $false
                customrules             = $null
                globaltechniqueoverrides = $null
            }
        }
        @{
            Name        = 'Audit MEM'
            Description = 'Basic MEM enabled with global audit mode — all techniques audit-only'
            Enabled     = $true
            Configuration = @{
                enabled                 = $true
                enableadvanced          = $false
                enablejavaprotection    = $false
                disabledefaultrules     = $false
                globalauditmodeoverride = $true
                customrules             = $null
                globaltechniqueoverrides = $null
            }
        }
    )
}
