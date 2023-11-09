Function Get-SEPMVersion {
    <# 
    .SYNOPSIS
        Gets the current version of Symantec Endpoint Protection Manager.
    .DESCRIPTION
        Gets the current version of Symantec Endpoint Protection Manager. This function dot not require authentication.
    .EXAMPLE
        PS C:\GitHub_Projects\PSSymantecSEPM> Get-SEPMVersion

        API_SEQUENCE API_VERSION version
        ------------ ----------- -------
        230504014    14.3.7000   14.3.9816.7000

        Gets the current version of Symantec Endpoint Protection Manager.
    #>
    

    # initialize the configuration
    $test_token = Test-SEPMAccessToken
    if ($test_token -eq $false) {
        Get-SEPMAccessToken | Out-Null
    }
    $URI = $script:BaseURLv1 + "/version"
    $headers = @{
        "Authorization" = "Bearer " + $script:accessToken.token
        "Content"       = 'application/json'
    }
    $body = @{
    }
    $params = @{
        Method  = 'GET'
        Uri     = $URI
        headers = $headers
        Body    = ($body | ConvertTo-Json)
    }

    $resp = Invoke-ABRestMethod -params $params

    return $resp
}