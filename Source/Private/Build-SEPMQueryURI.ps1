function Build-SEPMQueryURI {
    <#
    .SYNOPSIS
        Constructs a URI from a base URI and query strings
    .DESCRIPTION
        Constructs a URI from a base URI and query strings
    .PARAMETER BaseURI
        The base URI to use
    .PARAMETER QueryStrings
        A hashtable of query strings to add to the URI
    .NOTES
        helper function
    .EXAMPLE
        $BaseURI = "https://gdc8ap0030:8446/sepm/api/v1/computers"
        $QueryStrings = @{
            sort      = "COMPUTER_NAME"
            pageIndex = 1
            pageSize  = 100
        }
        $URI = Build-SEPMQueryURI -BaseURI $BaseURI -QueryStrings $QueryStrings
    #>
    
    
    param (
        [string]$BaseURI,
        [hashtable]$QueryStrings
    )

    # Construct the URI
    $builder = New-Object System.UriBuilder($BaseURI)
    $query = [System.Web.HttpUtility]::ParseQueryString($builder.Query)
    foreach ($param in $QueryStrings.GetEnumerator()) {
        $query[$param.Key] = $param.Value
    }
    $builder.Query = $query.ToString()
    $BaseURI = $builder.ToString()

    return $BaseURI
}