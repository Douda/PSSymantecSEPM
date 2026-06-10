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
        [switch]
        $Sonar,

        # SecurityRiskCategory
        [Parameter(ParameterSetName = 'WindowsFile')]
        [Parameter(ParameterSetName = 'WindowsFolder')]
        [ValidateSet('AllScans', 'AutoProtect', 'ScheduledAndOndemand')]
        [string]
        $SecurityRiskCategory,

        # ApplicationControl
        [Parameter(ParameterSetName = 'WindowsFile')]
        [switch]
        $ApplicationControl,

        # AllScans
        [Parameter(ParameterSetName = 'WindowsFile')]
        [switch]
        $AllScans,

        # ExcludeChildProcesses
        [Parameter(ParameterSetName = 'WindowsFile')]
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

        # EnablePolicy
        [Parameter(ParameterSetName = 'Default')]
        [Parameter(ParameterSetName = 'WindowsFile')]
        [Parameter(ParameterSetName = 'WindowsFolder')]
        [Parameter(ParameterSetName = 'WindowsExtension')]
        [Parameter(ParameterSetName = 'Tamper')]
        [Parameter(ParameterSetName = 'MacFile')]
        [switch]
        $EnablePolicy,

        # DisablePolicy
        [Parameter(ParameterSetName = 'Default')]
        [Parameter(ParameterSetName = 'WindowsFile')]
        [Parameter(ParameterSetName = 'WindowsFolder')]
        [Parameter(ParameterSetName = 'WindowsExtension')]
        [Parameter(ParameterSetName = 'Tamper')]
        [Parameter(ParameterSetName = 'MacFile')]
        [switch]
        $DisablePolicy,

        # PolicyDescription
        [Parameter(ParameterSetName = 'Default')]
        [Parameter(ParameterSetName = 'WindowsFile')]
        [Parameter(ParameterSetName = 'WindowsFolder')]
        [Parameter(ParameterSetName = 'WindowsExtension')]
        [Parameter(ParameterSetName = 'Tamper')]
        [Parameter(ParameterSetName = 'MacFile')]
        [string]
        $PolicyDescription,

        # ScanType (WindowsFolder and WindowsExtension)
        [Parameter(ParameterSetName = 'WindowsFolder')]
        [Parameter(ParameterSetName = 'WindowsExtension')]
        [ValidateSet('All', 'SecurityRisk', 'SONAR', 'ApplicationControl', 'AllScans', 'AutoProtect', 'ScheduledAndOndemand')]
        [string]
        $ScanType = 'AllScans',

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
        [ValidateNotNullOrEmpty()]
        [ValidatePattern("^[A-Za-z]:\\(?:[^\\/:*?""<>|\r\n]+\\)*[^\\/:*?""<>|\r\n]+\.[^\\/:*?""<>|\r\n]+$")]
        [string]
        $TamperPath,

        # MacFile
        [Parameter(ParameterSetName = 'MacFile', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^/([^/ ]+(/|$))+[^/ ]+\.[^/ ]+$')]
        [string]
        $MacPath,

        # MacFilePathVariable
        [Parameter(ParameterSetName = 'MacFile')]
        [ValidateSet('[NONE]', '[HOME]', '[APPLICATION]', '[LIBRARY]')]
        [string]
        $MacPathVariable = '[NONE]'
    )

    begin {
        $session = Initialize-SEPMSession
        $URI = $session.BaseURLv2 + "/policies/exceptions"
    }

    process {
        # Validate mutual exclusivity
        if ($EnablePolicy -and $DisablePolicy) {
            throw "-EnablePolicy and -DisablePolicy cannot be specified together."
        }

        # Fetch policy summary and resolve PolicyID
        $policies = Get-SEPMPoliciesSummary
        $PolicyID = ($policies | Where-Object { $_.name -eq $PolicyName } | Select-Object -First 1).id

        # Validate PolicyName exists before making API call
        if (-not $PolicyID) {
            throw "Policy '$PolicyName' not found. Verify the policy name and try again."
        }

        # Instantiate the policy exception structure
        $ObjBody = [SEPMPolicyExceptionsStructure]::new()
        $ObjBody.name = $PolicyName

        # Dispatch hashtable: parameter set name → scriptblock
        $PSBP = $PSBoundParameters

        # Iterate bound scan-type parameters to set booleans and scancategory.
        # $PSBP.Keys enumerates all bound param names; only scan-type case
        # labels match, so unrelated params (PolicyName, Path, etc.) fall through.
        $dispatch = @{
            'WindowsFile' = {
                $props = @{
                    path         = $Path
                    pathvariable = $PathVariable
                    deleted      = $Remove.IsPresent
                }

                # Parse scan type parameters
                switch ($PSBP.Keys) {
                    'Sonar'              { $props.sonar = $true }
                    'SecurityRiskCategory' {
                        $props.securityrisk = $true
                        $props.scancategory = $SecurityRiskCategory
                    }
                    'ApplicationControl' { $props.applicationcontrol = $true }
                    'ExcludeChildProcesses' {
                        $props.applicationcontrol = $true
                        $props.recursive = $true
                    }
                    'AllScans' {
                        $props.securityrisk = $true
                        $props.sonar = $true
                        $props.applicationcontrol = $true
                        $props.scancategory = 'AllScans'
                    }
                }

                # If no scan type is provided, default to AllScans
                if (-not $props.ContainsKey('securityrisk') -and -not $props.ContainsKey('sonar') -and -not $props.ContainsKey('applicationcontrol')) {
                    $props.securityrisk = $true
                    $props.sonar = $true
                    $props.applicationcontrol = $true
                    $props.scancategory = 'AllScans'
                }

                $entry = $ObjBody.NewEntry('Files', $props)
                $ObjBody.AddEntry('Files', $entry)
            }
            'WindowsFolder'    = {
                # Default to 'All' for WindowsFolder when -ScanType not explicitly passed
                $folderScanType = if ($PSBP.ContainsKey('ScanType')) { $ScanType } else { 'All' }

                if ($SecurityRiskCategory -and $folderScanType -ne 'SecurityRisk') {
                    throw "The -SecurityRiskCategory parameter requires the -ScanType parameter to be set to 'SecurityRisk'."
                }

                $props = @{
                    directory    = $FolderPath
                    pathvariable = $PathVariable
                    scantype     = $folderScanType
                    deleted      = $Remove.IsPresent
                }

                if ($IncludeSubFolders) {
                    $props.recursive = $true
                }

                if ($folderScanType -eq 'SecurityRisk' -and $SecurityRiskCategory) {
                    $props.scancategory = $SecurityRiskCategory
                }

                $entry = $ObjBody.NewEntry('Directories', $props)
                $ObjBody.AddEntry('Directories', $entry)
            }
            'WindowsExtension' = {
                $existingPolicy = Get-SEPMExceptionPolicy -PolicyName $PolicyName
                $existingExts = $existingPolicy.configuration.extension_list.extensions

                if ($Remove.IsPresent) {
                    foreach ($ext in $Extensions) {
                        if ($ext -notin $existingExts) {
                            throw "Cannot remove Extension '$ext'. It is not in the exception list."
                        }
                    }
                    $resultExts = $existingExts | Where-Object { $_ -notin $Extensions }
                    $deleted = $true
                } else {
                    $resultExts = @($Extensions) + @($existingExts) | Sort-Object | Get-Unique
                    $deleted = $false
                }

                $entry = $ObjBody.NewEntry('Extensions', @{
                    extensions   = $resultExts
                    scancategory = $ScanType
                    deleted      = $deleted
                })
                $ObjBody.AddEntry('Extensions', $entry)
            }
            'Tamper'           = {
                $entry = $ObjBody.NewEntry('TamperFiles', @{
                    path         = $TamperPath
                    pathvariable = $PathVariable
                    deleted      = $Remove.IsPresent
                })
                $ObjBody.AddEntry('TamperFiles', $entry)
            }
            'MacFile'          = {
                $entry = $ObjBody.NewEntry('MacFiles', @{
                    path         = $MacPath
                    pathvariable = $MacPathVariable
                    deleted      = $Remove.IsPresent
                })
                $ObjBody.AddEntry('MacFiles', $entry)
            }
            'Default'          = {}
        }

        & $dispatch[$PSCmdlet.ParameterSetName]

        # Apply policy-level metadata mutations
        if ($EnablePolicy) {
            $ObjBody.enabled = $true
        }
        if ($DisablePolicy) {
            $ObjBody.enabled = $false
        }
        if ($PSBP.ContainsKey('PolicyDescription')) {
            $ObjBody.desc = $PolicyDescription
        }

        # Serialize body for PATCH.
        # Optimize-SEPMObject clones the class to a clean PSCustomObject tree,
        # strips null/empty top-level properties and configuration sub-properties,
        # and applies SEPM domain rules (mac, linux, extension_list).
        $ObjBody = Optimize-SEPMObject -InputObject $ObjBody
        $bodyJson = ConvertTo-SEPMJson -InputObject $ObjBody -Compress

        $patchUri = $URI + "/" + $PolicyID
        $resp = Invoke-SepmApi -Method 'PATCH' -Uri $patchUri -Session $session `
            -Body $bodyJson -ContentType 'application/json'
        return $resp
    }
}
