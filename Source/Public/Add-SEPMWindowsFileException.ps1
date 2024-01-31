function Add-SEPMWindowsFileException {

    <#
    .SYNOPSIS
        Add a Windows File Exception to a Symantec Endpoint Protection Manager Policy
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
    .PARAMETER ApplicationControl
        Add the exception to the Application Control exclusions
    .PARAMETER ExcludeChildProcesses
        Exclude child processes from the Application Control exclusions
        Requires ApplicationControl to be set to true
    .PARAMETER SkipCertificateCheck
        Skip the certificate check when connecting to the SEPM
    .PARAMETER AllScans
        Add the exception to all scan types
        Equivalent to setting Sonar, SecurityRiskCategory and ApplicationControl to true
        If no scan type is provided, default to AllScans
    .EXAMPLE
        Add-SEPMWindowsFileException -PolicyName "Workstations Default Exception Policy" -Path "C:\Temp\file1.exe" -Sonar

        Exclude the file C:\Temp\file1.exe from SONAR scans in the policy Default
    .EXAMPLE
        Add-SEPMWindowsFileException -PolicyName "Workstations Default Exception Policy" -Path "C:\Temp\file1.exe" -SecurityRiskCategory "AllScans"

        Exclude the file C:\Temp\file1.exe from all Security Risk scans in the policy Default
    .EXAMPLE
        Add-SEPMWindowsFileException -PolicyName "Workstations Default Exception Policy" -Path "C:\Temp\file1.exe" -ApplicationControl

        Exclude the file C:\Temp\file1.exe from Application Control scans in the policy Default
    .EXAMPLE
        Add-SEPMWindowsFileException -PolicyName "Workstations Default Exception Policy" -Path "C:\Temp\file1.exe" -ApplicationControl -ExcludeChildProcesses

        Exclude the file C:\Temp\file1.exe from Application Control scans in the policy Default and exclude child processes
    .EXAMPLE
        Add-SEPMWindowsFileException -PolicyName "Workstations Default Exception Policy" -Path "C:\Temp\file1.exe" -AllScans

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

        # Sonar
        [Parameter(ParameterSetName = 'WindowsFileException')]
        [switch]
        $Sonar,

        # Scancategory - requires securityrisk to be set to true
        [Parameter(ParameterSetName = 'WindowsFileException')]
        [ValidateSet(
            'AllScans',
            'AutoProtect',
            'ScheduledAndOndemand'
        )]
        [string] 
        $SecurityRiskCategory,

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
        $Path,

        # Applicationcontrol
        [Parameter(ParameterSetName = 'WindowsFileException')]
        [switch]
        $ApplicationControl,

        # AllScans
        [Parameter(ParameterSetName = 'WindowsFileException')]
        [switch]
        $AllScans,

        # Recursive - requires applicationcontrol to be set to true
        [Parameter(ParameterSetName = 'WindowsFileException')]
        [ValidateScript({
                if (-not $ApplicationControl) {
                    throw "-ExcludeChildProcesses exception requires the -ApplicationControl switch to be set."
                }
                return $true
            })]
        [switch]
        $ExcludeChildProcesses
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

        # Parse the optional parameters
        switch ($PSBoundParameters.Keys) {
            "Sonar" {
                $ExceptionParams.sonar = $true
            }
            "DeleteException" {
                $ExceptionParams.deleted = $true
            }
            "SecurityRiskCategory" {
                $ExceptionParams.securityrisk = $true
                $ExceptionParams.scancategory = $SecurityRiskCategory
            }
            "ApplicationControl" {
                $ExceptionParams.applicationcontrol = $true
            }
            "ExcludeChildProcesses" {
                $ExceptionParams.applicationcontrol = $true
                $ExceptionParams.recursive = $true
            }
            "AllScans" {
                $ExceptionParams.securityrisk = $true
                $ExceptionParams.sonar = $true
                $ExceptionParams.applicationcontrol = $true
                $ExceptionParams.scancategory = "AllScans"
            }
        }

        # If no scan type is provided, default to AllScans
        if (-not $ExceptionParams.securityrisk -and -not $ExceptionParams.sonar -and -not $ExceptionParams.applicationcontrol) {
            $ExceptionParams.securityrisk = $true
            $ExceptionParams.sonar = $true
            $ExceptionParams.applicationcontrol = $true
            $ExceptionParams.scancategory = "AllScans"
        }

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