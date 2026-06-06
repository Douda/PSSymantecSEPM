function Update-SEPMExceptionPolicy {
    <#
    .SYNOPSIS
        Update exception policy rules in a Symantec Endpoint Protection Manager Policy.
    .DESCRIPTION
        Update exception policy rules in a Symantec Endpoint Protection Manager Policy.
        Supports adding and removing Windows file, folder, extension, tamper protection,
        Mac file exceptions, and a default parameter set.
    .PARAMETER PolicyName
        Name of the policy to update.
    .PARAMETER Path
        Path to add or remove from the exception list.
    .PARAMETER PathVariable
        Path variable to use for the path.
    .PARAMETER Sonar
        Add the exception to the SONAR exclusions.
    .PARAMETER SecurityRiskCategory
        Add the exception to the Security Risk exclusions.
    .PARAMETER ApplicationControl
        Add the exception to the Application Control exclusions.
    .PARAMETER AllScans
        Add the exception to all scan types.
    .PARAMETER ExcludeChildProcesses
        Exclude child processes from the Application Control exclusions.
    .PARAMETER Remove
        Remove the exception instead of adding it.
    #>

    [CmdletBinding(DefaultParameterSetName = 'Default')]
    param (
        # Policy Name
        [Parameter(
            Mandatory = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [String]
        $PolicyName,

        # Path
        [Parameter(ParameterSetName = 'WindowsFile', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern("^[A-Za-z]:\\(?:[^\\/:*?""<>|\r\n]+\\)*[^\\/:*?""<>|\r\n]+\.[^\\/:*?""<>|\r\n]+$")]
        [string]
        $Path,

        # PathVariable
        [Parameter(ParameterSetName = 'WindowsFile')]
        [Parameter(ParameterSetName = 'WindowsFolder')]
        [Parameter(ParameterSetName = 'Tamper')]
        [Parameter(ParameterSetName = 'MacFile')]
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

        # Sonar
        [Parameter(ParameterSetName = 'WindowsFile')]
        [Parameter(ParameterSetName = 'Tamper')]
        [switch]
        $Sonar,

        # SecurityRiskCategory
        [Parameter(ParameterSetName = 'WindowsFile')]
        [Parameter(ParameterSetName = 'WindowsFolder')]
        [Parameter(ParameterSetName = 'Tamper')]
        [ValidateSet('AllScans', 'AutoProtect', 'ScheduledAndOndemand')]
        [string]
        $SecurityRiskCategory,

        # ApplicationControl
        [Parameter(ParameterSetName = 'WindowsFile')]
        [Parameter(ParameterSetName = 'Tamper')]
        [switch]
        $ApplicationControl,

        # AllScans
        [Parameter(ParameterSetName = 'WindowsFile')]
        [Parameter(ParameterSetName = 'Tamper')]
        [switch]
        $AllScans,

        # ExcludeChildProcesses
        [Parameter(ParameterSetName = 'WindowsFile')]
        [Parameter(ParameterSetName = 'Tamper')]
        [ValidateScript({
            if (-not $ApplicationControl) {
                throw "-ExcludeChildProcesses requires the -ApplicationControl switch."
            }
            return $true
        })]
        [switch]
        $ExcludeChildProcesses,

        # Remove
        [Parameter(ParameterSetName = 'WindowsFile')]
        [Parameter(ParameterSetName = 'WindowsFolder')]
        [Parameter(ParameterSetName = 'WindowsExtension')]
        [Parameter(ParameterSetName = 'Tamper')]
        [Parameter(ParameterSetName = 'MacFile')]
        [switch]
        $Remove,

        # ScanType
        [Parameter(ParameterSetName = 'WindowsFolder')]
        [ValidateSet('All', 'SecurityRisk', 'SONAR', 'ApplicationControl')]
        [string]
        $ScanType = 'All',

        # IncludeSubFolders
        [Parameter(ParameterSetName = 'WindowsFolder')]
        [switch]
        $IncludeSubFolders,

        # -- Placeholder parameters for non-implemented parameter sets --

        # WindowsFolder
        [Parameter(ParameterSetName = 'WindowsFolder', Mandatory = $true)]
        [string]
        $FolderPath,

        # WindowsExtension
        [Parameter(ParameterSetName = 'WindowsExtension', Mandatory = $true)]
        [string[]]
        $Extensions,

        # Tamper
        [Parameter(ParameterSetName = 'Tamper', Mandatory = $true)]
        [string]
        $TamperPath,

        # MacFile
        [Parameter(ParameterSetName = 'MacFile', Mandatory = $true)]
        [string]
        $MacPath
    )

    begin {
        $session = Initialize-SEPMSession
        $URI = $session.BaseURLv2 + "/policies/exceptions"
    }

    process {
        # Fetch policy summary and resolve PolicyID
        $policies = Get-SEPMPoliciesSummary
        $PolicyID = $policies | Where-Object { $_.name -eq $PolicyName } | Select-Object -ExpandProperty id

        # Instantiate the policy exception structure
        $ObjBody = [SEPMPolicyExceptionsStructure]::new()
        $ObjBody.name = $PolicyName

        # Dispatch hashtable: parameter set name → scriptblock
        $PSBP = $PSBoundParameters
        $dispatch = @{
            'WindowsFile' = {
                $ExceptionParams = @{}
                $ExceptionParams.path = $Path
                $ExceptionParams.pathvariable = $PathVariable
                $ExceptionParams.RulestateSource = $script:ModuleName
                $ExceptionParams.deleted = $Remove.IsPresent

                # Parse scan type parameters
                switch ($PSBP.Keys) {
                    'Sonar'              { $ExceptionParams.sonar = $true }
                    'SecurityRiskCategory' {
                        $ExceptionParams.securityrisk = $true
                        $ExceptionParams.scancategory = $SecurityRiskCategory
                    }
                    'ApplicationControl' { $ExceptionParams.applicationcontrol = $true }
                    'ExcludeChildProcesses' {
                        $ExceptionParams.applicationcontrol = $true
                        $ExceptionParams.recursive = $true
                    }
                    'AllScans' {
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

                $FilesHashTable = $ObjBody.CreateFilesHashTable(
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

                $ObjBody.AddConfigurationFilesExceptions($FilesHashTable)

            }
            'WindowsFolder'    = {
                if ($SecurityRiskCategory -and $ScanType -ne 'SecurityRisk') {
                    throw "The -SecurityRiskCategory parameter requires the -ScanType parameter to be set to 'SecurityRisk'."
                }

                $ExceptionParams = @{}
                $ExceptionParams.directory = $FolderPath
                $ExceptionParams.pathvariable = $PathVariable
                $ExceptionParams.scantype = $ScanType
                $ExceptionParams.RulestateSource = $script:ModuleName
                $ExceptionParams.deleted = $Remove.IsPresent

                if ($IncludeSubFolders) {
                    $ExceptionParams.recursive = $true
                }

                if ($ScanType -eq 'SecurityRisk' -and $SecurityRiskCategory) {
                    $ExceptionParams.scancategory = $SecurityRiskCategory
                }

                $DirectoryHashTable = $ObjBody.CreateDirectoryHashtable(
                    $ExceptionParams.deleted,
                    $ExceptionParams.RulestateEnabled,
                    $ExceptionParams.RulestateSource,
                    $ExceptionParams.scancategory,
                    $ExceptionParams.scantype,
                    $ExceptionParams.pathvariable,
                    $ExceptionParams.directory,
                    $ExceptionParams.recursive
                )

                $ObjBody.AddConfigurationDirectoriesExceptions($DirectoryHashTable)
            }
            'WindowsExtension' = { throw "Update-SEPMExceptionPolicy: WindowsExtension parameter set is not yet implemented." }
            'Tamper'           = { throw "Update-SEPMExceptionPolicy: Tamper parameter set is not yet implemented." }
            'MacFile'          = { throw "Update-SEPMExceptionPolicy: MacFile parameter set is not yet implemented." }
            'Default'          = { throw "Update-SEPMExceptionPolicy: No parameter set specified. Use one of: WindowsFile, WindowsFolder, WindowsExtension, Tamper, MacFile." }
        }

        & $dispatch[$PSCmdlet.ParameterSetName]

        # Optimize AFTER dispatch so object is cleaned in process scope
        $ObjBody = Optimize-ExceptionPolicyStructure -obj $ObjBody

        $params = @{
            Session     = $session
            Method      = 'PATCH'
            Uri         = $URI + "/" + $PolicyID
            Body        = $ObjBody | ConvertTo-Json -Depth 100 -Compress
        }

        $resp = Invoke-ABRestMethod -params $params
        return $resp
    }
}
