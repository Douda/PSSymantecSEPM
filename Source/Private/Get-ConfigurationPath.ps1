function Get-ConfigurationPath {
    <# TODO update help
    .SYNOPSIS
        returns hashtable object with the BaseURL, SepCloudCreds, SepCloudToken full path
    .DESCRIPTION
    .INPUTS
        None
    .OUTPUTS
        Hashtable
    #>

    @{
        BaseUrl         = "api.sep.securitycloud.symantec.com"
        $ServerAddress  = Read-Host -Prompt "Value"
        SepCloudCreds   = "$env:TEMP\SepCloudOAuthCredentials.xml"
        CachedTokenPath = "$env:TEMP\SepCloudCachedToken.xml"
    }

}
