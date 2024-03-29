function Add-SEPMMacFileException {

    <# TODO update help
    .SYNOPSIS
        Add a Mac File Exception to a Symantec Endpoint Protection Manager Policy
    .DESCRIPTION
        Add a Windows File Exception to a Symantec Endpoint Protection Manager Policy
    .PARAMETER PolicyName
        Name of the policy to update
    .PARAMETER Path
        Path to add to the exception list
    .PARAMETER PathVariable
        Path variable to use for the path
    .PARAMETER Sonar
        Add the exception to the SONAR exclusions
    .PARAMETER SecurityRiskCategory
        Add the exception to the Security Risk exclusions
        Takes the following values:
            AllScans
            AutoProtect
            ScheduledAndOndemand
    .PARAMETER SkipCertificateCheck
        Skip the certificate check when connecting to the SEPM
    .EXAMPLE
        Add-SEPMMacFileException -PolicyName "Workstations Default Exception Policy" -Path "C:\Temp\file1.exe" -Sonar

        Exclude the file C:\Temp\file1.exe from SONAR scans in the policy Default
    .EXAMPLE
        Add-SEPMMacFileException -PolicyName "Workstations Default Exception Policy" -Path "C:\Temp\file1.exe" -SecurityRiskCategory "AllScans"

        Exclude the file C:\Temp\file1.exe from all Security Risk scans in the policy Default
    .EXAMPLE
        Add-SEPMMacFileException -PolicyName "Workstations Default Exception Policy" -Path "C:\Temp\file1.exe" -ApplicationControl

        Exclude the file C:\Temp\file1.exe from Application Control scans in the policy Default
    .EXAMPLE
        Add-SEPMMacFileException -PolicyName "Workstations Default Exception Policy" -Path "C:\Temp\file1.exe" -ApplicationControl -ExcludeChildProcesses

        Exclude the file C:\Temp\file1.exe from Application Control scans in the policy Default and exclude child processes
    .EXAMPLE
        Add-SEPMMacFileException -PolicyName "Workstations Default Exception Policy" -Path "C:\Temp\file1.exe" -AllScans

        Exclude the file C:\Temp\file1.exe from all scan types in the policy Default (SONAR / AutoProtect / Scheduled scans / Application Control)
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

        # Scancategory - requires securityrisk to be set to true
        [ValidateSet(
            'AllScans',
            'AutoProtect',
            'ScheduledAndOndemand'
        )]
        [ValidateScript({
                if ($ScanType -ne "SecurityRisk") {
                    throw "The -SecurityRiskCategory parameter requires the -ScanType parameter to be set to 'SecurityRisk'."
                }
                return $true
            })]
        [string] 
        $SecurityRiskCategory,

        # Pathvariable
        [ValidateSet(
            '[NONE]', 
            '[HOME]', 
            '[APPLICATION]', 
            '[LIBRARY ]'
        )]
        [string] 
        $PathVariable = "[NONE]",

        # Path
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern("^/([^/ ]+(/|$))+[^/ ]+\.[^/ ]+$")]
        [string] 
        $Path,

        # ScanType 
        [ValidateSet(
            'SecurityRisk',
            'SONAR',
            'All'
        )]
        [string]
        $ScanType = 'All'
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

        # Init & populate the mandatory parameters
        $ExceptionParams = @{}
        $ExceptionParams.path = $path
        $ExceptionParams.pathvariable = $PathVariable
        $ExceptionParams.RulestateSource = $script:ModuleName

        # API does not support seem to support scan type for Mac exceptions
        # TODO: Test for scan types and report potential issue to Symantec

        # # Parse the optional parameters
        # switch ($PSBoundParameters.Keys) {
        #     "SecurityRiskCategory" {
        #         $ExceptionParams.securityrisk = $true
        #         $ExceptionParams.scancategory = $SecurityRiskCategory
        #     }
        # }

        # Create the file exception object with CreateFilesHashTable
        # Method parameters have to be in the same order as in the method definition
        $DirectoryHashTable = $Policy.ObjBody.CreateMacFilesHashtable(
            $ExceptionParams.deleted,
            $ExceptionParams.RulestateEnabled,
            $ExceptionParams.RulestateSource,
            $ExceptionParams.pathvariable,
            $ExceptionParams.path
        )

        # Add the file exception parameters to the body structure
        $Policy.ObjBody.AddMacFiles($DirectoryHashTable)

        # Optimize the body structure (remove empty properties)
        $Policy.ObjBody = Optimize-ExceptionPolicyStructure -obj $Policy.ObjBody

        # TODO For testing only - remove this
        $Policy.ObjBody | ConvertTo-Json -Depth 100 | Out-File .\Data\PolicyStructure.json -Force

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