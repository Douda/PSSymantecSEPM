function Remove-SEPMWindowsFileException {

    <#
    .SYNOPSIS
        Remove a Windows File Exception from a Symantec Endpoint Protection Manager Policy
    .DESCRIPTION
        Remove a Windows File Exception from a Symantec Endpoint Protection Manager Policy
    .PARAMETER PolicyName
        Name of the policy to update
    .PARAMETER Path
        Path to add to the exception list
    .PARAMETER PathVariable
        Path variable to use for the path
    .PARAMETER SkipCertificateCheck
        Skip the certificate check when connecting to the SEPM
    .EXAMPLE
        Remove-SEPMWindowsFileException -PolicyName "Default" -Path "C:\Temp\file1.exe"
    
        Remove the file C:\Temp\file1.exe from the exception list in the policy Default
    #>
    
    
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
        [Parameter(ParameterSetName = 'WindowsFileException')]
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
        [Alias('WindowsPathVariable')]
        [string] 
        $PathVariable = "[NONE]",

        # Path
        [Parameter(ParameterSetName = 'WindowsFileException', Mandatory = $true)]
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
        $ExceptionParams.deleted = $true

        # Create the file exception object with CreateFilesHashTable
        # Method parameters have to be in the same order as in the method definition
        $FilesHashTable = $Policy.ObjBody.CreateFilesHashTable(
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

        # Add the file exception parameters to the body structure
        $Policy.ObjBody.AddConfigurationFilesExceptions($FilesHashTable)

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