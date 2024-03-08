function Add-SEPMWindowsTamperProtectionException {

    <#
    .SYNOPSIS
        Add aTamper Protection Exception to a Symantec Endpoint Protection Manager Policy
    .DESCRIPTION
        Add aTamper Protection Exception to a Symantec Endpoint Protection Manager Policy
    .PARAMETER PolicyName
        Name of the policy to update
    .PARAMETER Path
        Path to add to the exception list
    .PARAMETER PathVariable
        Path variable to use for the path
        Following values are allowed:
            [NONE]
            [COMMON_APPDATA]
            [COMMON_DESKTOPDIRECTORY]
            [COMMON_DOCUMENTS]
            [COMMON_PROGRAMS]
            [COMMON_STARTUP]
            [PROGRAM_FILES]
            [PROGRAM_FILES_COMMON]
            [SYSTEM]
            [SYSTEM_DRIVE]
            [USER_PROFILE]
            [WINDOWS]
    .EXAMPLE
        Add-SEPMWindowsTamperProtectionException -PolicyName "Workstations Default Exception Policy" -Path "C:\Temp\file1.exe"

        Exclude the file C:\Temp\file1.exe from Tamper Protection scans in the policy Default
    .EXAMPLE
        Add-SEPMWindowsTamperProtectionException -PolicyName "Workstations Default Exception Policy" -Path ".gitconfig -PathVariable [USER_PROFILE]

        Exclude the file .gitconfig located in the %USERPROFILE% from Tamper Protection scans in the policy Default
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

        # Pathvariable
        [ValidateSet(
            '[NONE]', 
            '[COMMON_APPDATA]', 
            '[COMMON_DESKTOPDIRECTORY]', 
            '[COMMON_DOCUMENTS]', 
            '[COMMON_PROGRAMS]', 
            '[COMMON_STARTUP]', 
            '[PROGRAM_FILES]', 
            '[PROGRAM_FILES_COMMON]', 
            '[SYSTEM]', 
            '[SYSTEM_DRIVE]', 
            '[USER_PROFILE]', 
            '[WINDOWS]'
        )]
        [string] 
        $PathVariable = "[NONE]",

        # Path
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern("^[A-Za-z]:\\(?:[^\\/:*?""<>|\r\n]+\\)*[^\\/:*?""<>|\r\n]+\.[^\\/:*?""<>|\r\n]+$")]
        [Alias('WindowsPath')]
        [string] 
        $Path
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

        # Create the Tamper Protection exception object with CreateTamperFilesHashtable
        # Method parameters have to be in the same order as in the method definition
        $TamperHashTable = $Policy.ObjBody.CreateTamperFilesHashtable(
            $ExceptionParams.sonar,
            $ExceptionParams.deleted,
            $ExceptionParams.RulestateEnabled,
            $ExceptionParams.RulestateSource,
            $ExceptionParams.scancategory,
            $ExceptionParams.pathvariable,
            $ExceptionParams.path,
            $ExceptionParams.applicationcontrol,
            $ExceptionParams.securityrisk,
            $ExceptionParams.recursive
        )

        # Add the tamper exception parameters to the body structure
        $Policy.ObjBody.AddTamperFiles($TamperHashTable)

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