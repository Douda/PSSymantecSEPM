function Send-SEPMCommandGetFile {
    <#
    .SYNOPSIS
        Sends a commands to request a suspicious file be uploaded back to Symantec Endpoint Protection Manager
    .DESCRIPTION
        Sends a commands to request a suspicious file be uploaded back to Symantec Endpoint Protection Manager
    .PARAMETER ComputerName
        The list of computers on which to search for the suspicious file.
    .PARAMETER SHA256
        SHA256 hash of the suspicious file.
    .PARAMETER MD5
        MD5 hash of the suspicious file.
    .PARAMETER SHA1
        SHA1 hash of the suspicious file.
    .PARAMETER Source
        The source to search for the suspicious file
        Possible values are: FILESYSTEM (default), QUARANTINE, or BOTH. 12.1.x clients only use FILESYSTEM.
    .PARAMETER FilePath
        The file path of the suspicious file.
    .EXAMPLE
        PS C:\PSSymantecSEPM> Send-SEPMCommandGetFile -ComputerName MyWorkstation01 -SHA256 1234567890123456789012345678901234567890123456789012345678901234 -FilePath C:\Temp\malware.exe -Source BOTH

        Sends a command to request the following file C:\Temp\malware.exe be uploaded from MyWorkstation01 to Symantec Endpoint Protection Manager.
        Requests includes both the file system and quarantine locations to be looked at.
    #>
    
    
    [CmdletBinding()]
    param (
        # The list of computers on which to search for the suspicious file.
        [Parameter(
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [Alias("Hostname", "DeviceName", "Device", "Computer")]
        [String]
        $ComputerName,

        # SHA256 hash of the suspicious file.
        [Parameter(ParameterSetName = 'SHA256Hash')]
        [ValidateScript({
                if ($_.Length -ne 64) { throw "SHA256 hash must be 64 characters long" }
                return $true
            })]
        [string]
        $SHA256,

        # MD5 hash of the suspicious file.
        [Parameter(ParameterSetName = 'MD5Hash')]
        [ValidateScript({
                if ($_.Length -ne 32) { throw "MD5 hash must be 32 characters long" }
                return $true
            })]
        [string]
        $MD5,

        # SHA1 hash of the suspicious file.
        [Parameter(ParameterSetName = 'SHA1Hash')]
        [ValidateScript({
                if ($_.Length -ne 40) { throw "SHA1 hash must be 40 characters long" }
                return $true
            })]
        [string]
        $SHA1,

        # The source to search for the suspicious file
        [Parameter()]
        [ValidateSet('FILESYSTEM ', 'QUARANTINE', 'BOTH')]
        [string]
        $Source,

        # The file path of the suspicious file.
        [Parameter()]
        [ValidateScript({
                if ($_ -notmatch '^.+\\[^\\]+\.[^\\]+$') { 
                    throw "The string must be a file path ending with a file name and an extension" 
                }
                return $true
            })]
        [Alias("Path")]
        [string]
        $FilePath
    )
    
    begin {
        # initialize the configuration
        $test_token = Test-SEPMAccessToken
        if (-not $test_token){
            Get-SEPMAccessToken | Out-Null
        }
        $headers = @{
            "Authorization" = "Bearer " + $script:accessToken.token
            "Content"       = 'application/json'
        }
    }
    
    process {
        # Get computer ID(s) from computer name(s)
        $ComputerIDList = @()
        foreach ($C in $ComputerName) {
            $ComputerID = Get-SEPComputers -ComputerName $C | Select-Object -ExpandProperty uniqueId
            $ComputerIDList += $ComputerID
        }

        $URI = $script:BaseURLv1 + "/command-queue/files"

        # URI query strings
        $QueryStrings = @{
            computer_ids = $ComputerIDList
            file_path    = $FilePath
            source       = $Source
        }

        # Add correct hash to query strings
        if ($SHA256) {
            $QueryStrings.Add("sha256", $SHA256)
        } elseif ($MD5) {
            $QueryStrings.Add("md5", $MD5)
        } elseif ($SHA1) {
            $QueryStrings.Add("sha1", $SHA1)
        }

        # Construct the URI
        $URI = Build-SEPMQueryURI -BaseURI $URI -QueryStrings $QueryStrings

        # prepare the parameters
        $params = @{
            Method  = 'POST'
            Uri     = $URI
            headers = $headers
        }

        $resp = Invoke-ABRestMethod -params $params
        return $resp
    }
}