@{
    Policies = @(
        @{
            Name        = 'TDAD Enabled'
            Description = 'Targeted Data Analytics Data — enabled with empty AD domain list'
            Enabled     = $true
            Configuration = @{
                enabled    = $true
                ad_domains = @()
            }
        }
        @{
            Name        = 'TDAD Disabled'
            Description = 'Targeted Data Analytics Data — disabled with empty AD domain list'
            Enabled     = $false
            Configuration = @{
                enabled    = $false
                ad_domains = @()
            }
        }
    )
}
