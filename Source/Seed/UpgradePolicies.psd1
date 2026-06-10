@{
    Policies = @(
        @{
            Name        = 'Zero-Day Upgrade'
            Description = 'Immediate upgrade on all days with large distribution window and retries enabled'
            Enabled     = $true
            Configuration = @{
                release_delay_days = 0
                schedule           = @{
                    daily         = @{
                        monday    = $true
                        tuesday   = $true
                        wednesday = $true
                        thursday  = $true
                        friday    = $true
                        saturday  = $true
                        sunday    = $true
                        time      = '0000-00-00T00:00:00.000Z'
                    }
                    end_time      = '0000-00-00T23:59:59.000Z'
                    retry_enabled = $true
                    time_window   = 86400
                }
            }
        }
        @{
            Name        = 'Weekend Upgrade'
            Description = 'One-week delay with weekend-only window and retries enabled'
            Enabled     = $true
            Configuration = @{
                release_delay_days = 7
                schedule           = @{
                    daily         = @{
                        monday    = $false
                        tuesday   = $false
                        wednesday = $false
                        thursday  = $false
                        friday    = $false
                        saturday  = $true
                        sunday    = $true
                        time      = '0000-00-00T00:00:00.000Z'
                    }
                    end_time      = '0000-00-00T04:00:00.000Z'
                    retry_enabled = $true
                    time_window   = 14400
                }
            }
        }
        @{
            Name        = 'Manual Upgrade'
            Description = 'Upgrade policy disabled — no automatic schedule applied'
            Enabled     = $false
            Configuration = @{
                release_delay_days = 0
                schedule           = @{
                    daily         = @{
                        monday    = $false
                        tuesday   = $false
                        wednesday = $false
                        thursday  = $false
                        friday    = $false
                        saturday  = $false
                        sunday    = $false
                        time      = '0000-00-00T00:00:00.000Z'
                    }
                    end_time      = '0000-00-00T00:00:00.000Z'
                    retry_enabled = $false
                    time_window   = 0
                }
            }
        }
    )
}
