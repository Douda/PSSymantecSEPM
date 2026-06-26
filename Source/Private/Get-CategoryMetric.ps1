function Get-CategoryMetric {
    <#
    .SYNOPSIS
        Returns a human-readable metric string for a given inventory category.

    .DESCRIPTION
        Takes a category name and data object, returns a formatted metric string
        suitable for verbose output in Export-SEPMInventory. Handles null data
        (returns empty string) and failed categories (returns 'error').

        Contains the full switch statement mapping each of the 25 inventory
        categories to a descriptive metric (e.g. "3 domains", "5 policies").

    .PARAMETER Category
        The inventory category name (e.g. 'Domains', 'Computers', 'Version').

    .PARAMETER Data
        The data object for the category. Can be an array, hashtable,
        PSCustomObject, or null.

    .PARAMETER Failed
        If $true, returns 'error' regardless of data.

    .EXAMPLE
        Get-CategoryMetric -Category 'Domains' -Data @('domain1', 'domain2', 'domain3')
        # Returns "3 domains"

    .EXAMPLE
        Get-CategoryMetric -Category 'Computers' -Data $null
        # Returns ""

    .EXAMPLE
        Get-CategoryMetric -Category 'Version' -Data @{ API_VERSION = '14.3' }
        # Returns "14.3"
    #>

    [CmdletBinding()]
    param(
        [string]$Category,
        [object]$Data,
        [bool]$Failed = $false
    )

    if ($Failed) { return 'error' }
    if ($null -eq $Data) { return '' }

    $count = @($Data).Count

    switch ($Category) {
        'Version' {
            if ($Data -is [hashtable] -or $Data -is [PSCustomObject]) {
                $v = if ($Data.version) { $Data.version } elseif ($Data.API_VERSION) { $Data.API_VERSION } else { $Data }
                return "$v"
            }
            return "$count entries"
        }
        'Domains' { return "$count domain$(if($count -eq 1){''}else{'s'})" }
        'GUPs' { return "$count GUP$(if($count -eq 1){''}else{'s'})" }
        'Admins' { return "$count admin$(if($count -eq 1){''}else{'s'})" }
        'DatabaseInfo' { return "$($Data.type)" }
        'License' { return "$($Data.productName)" }
        'LicenseSummary' { return "$($Data.license_type)" }
        'ReplicationStatus' { return "$count site$(if($count -eq 1){''}else{'s'})" }
        'ThreatStats' { return "$count stat$(if($count -eq 1){''}else{'s'})" }
        'LatestDefinitions' { return "$($Data.contentName)" }
        'Events' { return "$count event$(if($count -eq 1){''}else{'s'})" }
        'PolicySummaries' { return "$count polic$(if($count -eq 1){'y'}else{'ies'})" }
        'FirewallPolicies' { return "$count polic$(if($count -eq 1){'y'}else{'ies'})" }
        'IpsPolicies' { return "$count polic$(if($count -eq 1){'y'}else{'ies'})" }
        'ExceptionPolicies' { return "$count polic$(if($count -eq 1){'y'}else{'ies'})" }
        'Computers' { return "$count computer$(if($count -eq 1){''}else{'s'})" }
        'ClientStatus' { return "$count statu$(if($count -eq 1){'s'}else{'ses'})" }
        'ClientVersions' { return "$count entr$(if($count -eq 1){'y'}else{'ies'})" }
        'ClientDefVersions' { return "$count entr$(if($count -eq 1){'y'}else{'ies'})" }
        'ClientInfected' { return "$count client$(if($count -eq 1){''}else{'s'})" }
        'Groups' { return "$count group$(if($count -eq 1){''}else{'s'})" }
        'Locations' { return "$count location$(if($count -eq 1){''}else{'s'})" }
        'LocationXML' { return "$count entr$(if($count -eq 1){'y'}else{'ies'})" }
        'GroupSettings' { return "$count entr$(if($count -eq 1){'y'}else{'ies'})" }
        'HostGroups' { return "$count group$(if($count -eq 1){''}else{'s'})" }
        'Snapshot' { return 'snapshot written' }
        default { return "$count entries" }
    }
}
