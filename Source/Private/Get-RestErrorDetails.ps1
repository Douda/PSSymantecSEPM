Function Get-RestErrorDetails {
    <#
    .SYNOPSIS
    Provides basic Rest Error Information from the API call in the event that the REST API call could not be performed successfully.

    .EXAMPLE
    try{
        Invoke-RestMethod -Method GET -URI $URI -headers $headers
    }catch{
        Get-RestErrorDetails
    }
    #>
    "An error was found with this command. Please review the resultant error for details."
    "Error Code:" + $_.Exception.Response.StatusCode.Value__ + " " + $_.Exception.Response.ReasonPhrase
    "Error Message: " + $_
}