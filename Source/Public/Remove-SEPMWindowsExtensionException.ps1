function Remove-SEPMWindowsExtensionException {

    <#
    .SYNOPSIS
        Add a Windows extension exception to a SEPM policy
    .DESCRIPTION
        Add a Windows extension exception to a SEPM policy
    .PARAMETER PolicyName
        Name of the policy to update
    .PARAMETER Extension
        Extension to add to the exception list
        Accepts multiple values
    .PARAMETER ScanType
        Type of scan to apply the exception to
        Valid values are:
            AllScans
            AutoProtect
            ScheduledAndOndemand
    .EXAMPLE
        Add-SEPMWindowsExtensionException -PolicyName "Workstations Default Exception Policy" -Extension tmp,tmp2

        Add 2 Windows extensions exception, tmp and tmp2 to the "Workstations Default Exception Policy" policy
    .EXAMPLE
        Add-SEPMWindowsExtensionException -PolicyName "Workstations Default Exception Policy" -Extension tmp,tmp2 -ScanType AutoProtect

        Add 2 Windows extensions exception, tmp and tmp2 to the "Workstations Default Exception Policy" policy, for AutoProtect scans
    #>
    
    

    [CmdletBinding()]
    param (
        # Skip certificate check
        [Parameter()]
        [switch]
        $SkipCertificateCheck,

        # Policy Name
        [Parameter(
            ValueFromPipelineByPropertyName = $true,
            Mandatory = $true
        )]
        [String]
        $PolicyName,

        # Extension
        [Parameter(
            Mandatory = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $Extension,

        # Security Risk type
        [ValidateSet(
            'AllScans',
            'AutoProtect',
            'ScheduledAndOndemand'
        )]
        [string] 
        $ScanType = 'AllScans'
    )

    begin {
        # initialize the configuration
        $test_token = Test-SEPMAccessToken
        if (-not $test_token) {
            Get-SEPMAccessToken | Out-Null
        }
        if ($SkipCertificateCheck) {
            $script:SkipCert = $true
        }
        $URI = $script:BaseURLv2 + "/policies/exceptions"
        $headers = @{
            "Authorization" = "Bearer " + $script:accessToken.token
            "Content"       = 'application/json'
        }
    }

    process {
        # Initialize the policy exception
        $Policy = Initialize-PolicyExceptionStructure -PolicyName $PolicyName

        # Gather current extension exception list
        $PolicyExtList = (Get-SEPMExceptionPolicy -PolicyName $PolicyName).configuration.extension_list.extensions

        # Init & populate the mandatory parameters
        $ExceptionParams = @{}
        $ExtensionList = @()
        $ExceptionParams.RulestateSource = $script:ModuleName
        $ExceptionParams.scancategory = $ScanType

        # Populate extension list
        $ExtensionList += $PolicyExtList

        # Parse the extension list to remove
        foreach ($Ext in $Extension) {
            if ($ExtensionList -notcontains $Ext) {
                throw "Cannot remove Extension $Ext. It is not in the exception list"
            } else {
                $ExtensionList = $ExtensionList | Where-Object { $_ -ne $Ext }
            }
        }
        $ExceptionParams.extensions += $ExtensionList

        # Create the file exception object with CreateExtensionListHashtable
        # Method parameters have to be in the same order as in the method definition
        $ExtensionHashTable = $Policy.ObjBody.CreateExtensionListHashtable(
            $ExceptionParams.deleted,
            $ExceptionParams.RulestateEnabled,
            $ExceptionParams.RulestateSource,
            $ExceptionParams.scancategory,
            $ExceptionParams.extensions
        )

        # Add the file exception parameters to the body structure
        $Policy.ObjBody.AddExtensionsList($ExtensionHashTable)

        # Optimize the body structure (remove empty properties)
        $Policy.ObjBody = Optimize-ExceptionPolicyStructure -obj $Policy.ObjBody

        # TODO For testing only - remove this
        # $Policy.ObjBody | ConvertTo-Json -Depth 100 | Out-File .\Data\PolicyStructure.json -Force

        # prepare the parameters
        $params = @{
            Method      = 'PATCH'
            Uri         = $URI + "/" + $Policy.PolicyID
            headers     = $headers
            contenttype = 'application/json'
            Body        = $Policy.ObjBody | ConvertTo-Json -Depth 100
        }

        $resp = Invoke-ABRestMethod -params $params
        return $resp
    }
}