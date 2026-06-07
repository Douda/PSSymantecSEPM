function Get-SEPFileDetails {
    <#
    .SYNOPSIS
        Gets the details of a binary file, such as the checksum and the file size
    .DESCRIPTION
        Gets the details of a binary file, such as the checksum and the file size
    .PARAMETER FileID
        The ID of the file to get the details of
        Is a required parameter
        Can be found in the command ID of the response from Send-SEPMCommandGetFile
    .EXAMPLE
        PS C:\PSSymantecSEPM> Get-SEPFileDetails -FileID 12345678901234567890123456789

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
        $session = Initialize-SEPMSession
        $URI = $session.BaseURLv1 + "/command-queue/file/$FileID/details"

    }

    process {
        # URI query strings
        $QueryStrings = @{
            file_id = $FileID
        }

        # Construct the URI
        $URI = Build-SEPMQueryURI -BaseURI $URI -QueryStrings $QueryStrings

        $resp = Invoke-SepmApi -Method GET -Uri $URI -Session $session
        return $resp
    }
}
