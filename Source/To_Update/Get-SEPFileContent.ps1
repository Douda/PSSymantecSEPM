function Get-SEPFileContent {
    <# #TODO update help
    .SYNOPSIS
        Gets the details of a binary file, such as the checksum and the file size
    .DESCRIPTION
        Gets the details of a binary file, such as the checksum and the file size
    .PARAMETER FileID
        The ID of the file to get the details of
        Is a required parameter
        Can be found in the command ID of the response from Send-SEPMCommandGetFile
    .EXAMPLE
        PS C:\PSSymantecSEPM> Get-SEPFileContent -FileID 12345678901234567890123456789

        id                               fileSize checksum
        --                               -------- --------
        CD02BC8E0A6606D53533F2428BB86D4E  1071101 4BE0BB3B57044CAD186FB59C2B7A13BB
#>

    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $FileID
    )

    begin {
        # initialize the configuration
        $test_token = Test-SEPMAccessToken
        if (-not $test_token){
            Get-SEPMAccessToken | Out-Null
        }
        $URI = $script:BaseURLv1 + "/command-queue/file/$FileID/content"
        $headers = @{
            "Authorization" = "Bearer " + $script:accessToken.token
            "Content"       = 'application/json'
        }
    }

    process {
        # URI query strings
        $QueryStrings = @{}

        # Construct the URI
        $builder = New-Object System.UriBuilder($URI)
        $query = [System.Web.HttpUtility]::ParseQueryString($builder.Query)
        foreach ($param in $QueryStrings.GetEnumerator()) {
            $query[$param.Key] = $param.Value
        }
        $builder.Query = $query.ToString()
        $URI = $builder.ToString()

        $params = @{
            Method  = 'GET'
            Uri     = $URI
            headers = $headers
            OutFile = (Join-Path (Get-Location) "test.exe") # TODO: change this to a temp file
        }
    
        $resp = Invoke-ABRestMethod -params $params
        return $resp
    }
}