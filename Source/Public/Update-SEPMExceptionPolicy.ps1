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
                # Default to 'All' for WindowsFolder when -ScanType not explicitly passed
                $folderScanType = if ($PSBP.ContainsKey('ScanType')) { $ScanType } else { 'All' }

                if ($SecurityRiskCategory -and $folderScanType -ne 'SecurityRisk') {
                    throw "The -SecurityRiskCategory parameter requires the -ScanType parameter to be set to 'SecurityRisk'."
                }

                $ExceptionParams = @{}
                $ExceptionParams.directory = $FolderPath
                $ExceptionParams.pathvariable = $PathVariable
                $ExceptionParams.scantype = $folderScanType
                $ExceptionParams.RulestateSource = $script:ModuleName
                $ExceptionParams.deleted = $Remove.IsPresent

                if ($IncludeSubFolders) {
                    $ExceptionParams.recursive = $true
                }

                if ($folderScanType -eq 'SecurityRisk' -and $SecurityRiskCategory) {
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

                $extHash = $ObjBody.CreateExtensionListHashtable(
                    $deleted,
                    $null,
                    $script:ModuleName,
                    $ScanType,
                    $resultExts
                )

                $ObjBody.AddExtensionsList($extHash)
            }
            'Tamper'           = {
                $tamperHash = $ObjBody.CreateTamperFilesHashtable(
                    $null,                # sonar
                    $Remove.IsPresent,     # deleted
                    $null,                # rulestate_enabled
                    $script:ModuleName,   # rulestate_source
                    '',                    # scancategory
                    $PathVariable,        # pathvariable
                    $TamperPath,          # path
                    $null,                # applicationcontrol
                    $null,                # securityrisk
                    $null                 # recursive
                )
                $ObjBody.AddTamperFiles($tamperHash)
            }
            'MacFile'          = {
                $macHash = $ObjBody.CreateMacFilesHashtable(
                    $Remove.IsPresent,
                    $null,
                    $script:ModuleName,
                    $MacPathVariable,
                    $MacPath
                )
                $ObjBody.AddMacFiles($macHash)
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

        # Serialize body for PATCH
        if ($PSVersionTable.PSVersion.Major -ge 6) {
            # PS 7+: Optimize then serialize with full depth
            $ObjBody = Optimize-ExceptionPolicyStructure -obj $ObjBody
            $ObjBody = Optimize-ExceptionPolicyStructure -obj $ObjBody
            $bodyJson = $ObjBody | ConvertTo-Json -Depth 100 -Compress
        } else {
            # PS 5.1: Skip Optimize-ExceptionPolicyStructure (its ConvertTo-Json
            # roundtrip corrupts nested arrays on PS 5.1 due to depth truncation).
            # Empty-property stripping is handled inline below.
            $cleanConfig = @{}
            if ($null -ne $ObjBody.configuration) {
            # PS 5.1: configuration is [hashtable] (implements IDictionary).
            # Iterate keys directly instead of using PSObject.Properties.
            if ($ObjBody.configuration -is [System.Collections.IDictionary]) {
                foreach ($key in $ObjBody.configuration.Keys) {
                    $val = $ObjBody.configuration[$key]
                    $isEmpty = $false
                    if ($null -eq $val) { $isEmpty = $true }
                    elseif ($val -is [System.Collections.IList] -and $val.Count -eq 0) { $isEmpty = $true }
                    elseif ($val -is [System.Collections.IDictionary] -and $val.Count -eq 0) { $isEmpty = $true }
                    if ($key -eq 'mac' -and $val.files.Count -eq 0) { $isEmpty = $true }
                    if ($key -eq 'linux') {
                        $hasLinux = $val.directories.Count -gt 0
                        if ($val.extension_list -and $val.extension_list.extensions -and $val.extension_list.extensions.Count -gt 0) { $hasLinux = $true }
                        if (-not $hasLinux) { $isEmpty = $true }
                    }
                    if ($key -eq 'extension_list' -and $val.extensions.Count -eq 0) { $isEmpty = $true }
                    if (-not $isEmpty) { $cleanConfig[$key] = $val }
                }
            } else {
                foreach ($prop in $ObjBody.configuration.PSObject.Properties) {
                    if ($prop.MemberType -ne 'NoteProperty') { continue }
                    $val = $prop.Value
                    $isEmpty = $false
                    if ($null -eq $val) { $isEmpty = $true }
                    elseif ($val -is [System.Collections.IList] -and $val.Count -eq 0) { $isEmpty = $true }
                    elseif ($val -is [System.Collections.IDictionary] -and $val.Count -eq 0) { $isEmpty = $true }
                    if ($prop.Name -eq 'mac' -and $val.files.Count -eq 0) { $isEmpty = $true }
                    if ($prop.Name -eq 'linux') {
                        $hasLinux = $val.directories.Count -gt 0
                        if ($val.extension_list -and $val.extension_list.extensions -and $val.extension_list.extensions.Count -gt 0) { $hasLinux = $true }
                        if (-not $hasLinux) { $isEmpty = $true }
                    }
                    if ($prop.Name -eq 'extension_list' -and $val.extensions.Count -eq 0) { $isEmpty = $true }
                    if (-not $isEmpty) { $cleanConfig[$prop.Name] = $val }
                }
            }
            }
            $bodyObj = [PSCustomObject]@{ name = $ObjBody.name }
            if ($cleanConfig.Count -gt 0) {
                $bodyObj | Add-Member -NotePropertyName configuration -NotePropertyValue ([PSCustomObject]$cleanConfig)
            }
            if ($null -ne $ObjBody.enabled) { $bodyObj | Add-Member -NotePropertyName enabled -NotePropertyValue $ObjBody.enabled }
            if ($null -ne $ObjBody.desc)   { $bodyObj | Add-Member -NotePropertyName desc -NotePropertyValue $ObjBody.desc }
            # PS 5.1 ConvertTo-Json truncates at depth 2. Use a manual
            # JSON serializer (avoids JavaScriptSerializer PSObject wrapping bugs).
            function ConvertTo-JsonSafe {
                param($obj)
                $sb = New-Object System.Text.StringBuilder
                $nullRef = [ref]$null
                function _serialize {
                    param($o, $sb)
                    if ($null -eq $o) { [void]$sb.Append('null'); return }
                    if ($o -is [string]) {
                        [void]$sb.Append('"')
                        [void]$sb.Append($o.Replace('\', '\\').Replace('"', '\"').Replace("`n", '\n').Replace("`r", '\r').Replace("`t", '\t'))
                        [void]$sb.Append('"')
                        return
                    }
                    if ($o -is [bool]) { [void]$sb.Append($o.ToString().ToLowerInvariant()); return }
                    if ($o -is [int] -or $o -is [long] -or $o -is [double] -or $o -is [decimal]) { [void]$sb.Append($o); return }
                    # Unwrap PSObject (except PSCustomObject)
                    if ($o -is [PSObject] -and $o -isnot [PSCustomObject]) {
                        $baseObj = $o.PSObject.BaseObject
                        _serialize $baseObj $sb
                        return
                    }
                    if ($o -is [System.Collections.IList]) {
                        [void]$sb.Append('[')
                        $first = $true
                        foreach ($item in $o) {
                            if (-not $first) { [void]$sb.Append(',') }
                            _serialize $item $sb
                            $first = $false
                        }
                        [void]$sb.Append(']')
                        return
                    }
                    if ($o -is [System.Collections.IDictionary]) {
                        [void]$sb.Append('{')
                        $first = $true
                        foreach ($key in $o.Keys) {
                            if (-not $first) { [void]$sb.Append(',') }
                            _serialize ([string]$key) $sb
                            [void]$sb.Append(':')
                            _serialize $o[$key] $sb
                            $first = $false
                        }
                        [void]$sb.Append('}')
                        return
                    }
                    # PSCustomObject / PSObject with NoteProperties
                    if ($o -is [PSCustomObject] -or $o -is [PSObject]) {
                        [void]$sb.Append('{')
                        $first = $true
                        foreach ($prop in $o.PSObject.Properties) {
                            if ($prop.MemberType -eq 'NoteProperty') {
                                if (-not $first) { [void]$sb.Append(',') }
                                _serialize ([string]$prop.Name) $sb
                                [void]$sb.Append(':')
                                _serialize $prop.Value $sb
                                $first = $false
                            }
                        }
                        [void]$sb.Append('}')
                        return
                    }
                    # Fallback: ToString
                    _serialize ([string]$o.ToString()) $sb
                }
                _serialize $obj $sb
                return $sb.ToString()
            }
            $bodyJson = ConvertTo-JsonSafe $bodyObj
        }

        $patchUri = $URI + "/" + $PolicyID
        $resp = Invoke-SepmApi -Method 'PATCH' -Uri $patchUri -Session $session `
            -Body $bodyJson -ContentType 'application/json'
        return $resp
    }
}
