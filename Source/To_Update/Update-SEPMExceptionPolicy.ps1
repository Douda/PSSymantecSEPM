function Update-SEPMExceptionPolicy {
    <#
    .SYNOPSIS
        Update a Symantec Endpoint Protection Manager Exception Policy
    .DESCRIPTION
        Update a Symantec Endpoint Protection Manager Exception Policy
    .PARAMETER PolicyName
        The name of the policy to update
    .PARAMETER Description
        The description of the policy
    .PARAMETER EnablePolicy
        Enable the policy
    .PARAMETER DisablePolicy
        Disable the policy
    .PARAMETER WindowsFileException
        Add a Windows File Exception to the policy
    .PARAMETER WindowsFolderException
        Add a Windows Folder Exception to the policy
    .PARAMETER Sonar
        Add the SONAR type of scan to the exception
    .PARAMETER DeleteException
        Delete the exception
    .PARAMETER RulestateEnabled
        Enable the rule
    .PARAMETER RulestateDisabled
        Disable the rule
    .PARAMETER RulestateSource
        Source of the rule
        Default is the module name : PSSymantecSEPM
    .PARAMETER SecurityRiskCategory
        The type of security risk scan to add to the exception
        Valid values are :
            AllScans
            Auto-Protect
            ScheduledAndOndemand
    .PARAMETER PathVariable
        The path variable to use for the exception
        Valid values are :
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
    .PARAMETER Path
        The path to add to the exception
    .PARAMETER ApplicationControl
        Add the Application Control type of scan to the exception
    .PARAMETER AllScans
        Add all types of scans to the exception
        Based on the exception type
        AllScans is default if no scan type is provided
    .PARAMETER ExcludeChildProcesses
        Exclude child processes from the exception
        Specific to Application Control type of scan
        Requires ApplicationControl to be explicitly set to true
    .PARAMETER IncludeSubFolders
        Include subfolders in the exception
        Specific to Windows Folder Exception
    .PARAMETER ScanType
        The type of scan to add to the exception
        Valid values are :
            SecurityRisk
            SONAR
            ApplicationControl
            All
        Default value is All
    
    .EXAMPLE
        $params = @{
            PolicyName = "Workstations Exception Policy"
            WindowsFileException = $true
            AllScans = $true
            PathVariable = "[COMMON_DESKTOPDIRECTORY]"
            Path = "InternalApplication.exe"
        }
        Update-SEPMExceptionPolicy @params
        (Get-SEPMExceptionPolicy -PolicyName "Workstations Exception Policy").configuration.directories | Where-Object { $_.directory -match "InternalApplication.exe" }

        Using splatting, excludes the InternalApplication.exe file located in the Desktop directory from all types of scans
        Get-SEPMExceptionPolicy command verifies that the exception has been added to the policy
    
    .EXAMPLE
        Update-SEPMExceptionPolicy -PolicyName "Workstations Exception Policy" -Description "Default Workstations policy" -WindowsFileException -AllScans -PathVariable "[COMMON_DESKTOPDIRECTORY]" -Path "InternalApplication.exe"

        Same example without splatting, excludes the InternalApplication.exe file located in the Desktop directory from all types of scans
    
    .EXAMPLE
        $params = @{
            PolicyName = "Workstations Exception Policy"
            WindowsFileException = $true
            Sonar = $true
            Path = "C:\MyCorp\InternalApplication.exe"
        }
        Update-SEPMExceptionPolicy @params

        Using splatting, excludes the InternalApplication.exe file located in the C:\MyCorp directory from the SONAR type of scan
    
    .EXAMPLE
        $params = @{
            PolicyName = "Workstations Exception Policy"
            WindowsFileException = $true
            Path = "C:\MyCorp\InternalApplication.exe"
            DeleteException = $true
        }
        Update-SEPMExceptionPolicy @params

        Using splatting, deletes the exception for the InternalApplication.exe file located in the C:\MyCorp directory
    
    .EXAMPLE
        Update-SEPMExceptionPolicy -PolicyName "Workstations Exception Policy" -Path "C:\MyCorp\InternalApplication.exe" -DeleteException

        Same example without splatting, deletes the exception for the InternalApplication.exe file located in the C:\MyCorp directory
    
    .EXAMPLE
        Update-SEPMExceptionPolicy -PolicyName "Workstations Exception Policy" -WindowsFileException -Path "C:\Temp\File5.exe" -SecurityRiskCategory AutoProtect

        Excludes the File5.exe file located in the C:\Temp directory from the AutoProtect type of scan
    
    .EXAMPLE
        Update-SEPMExceptionPolicy -PolicyName "Workstations Exception Policy" -WindowsExtensionException extension1, extension2

        Excludes the extension1 and extension2 extensions from all types of scans
    
    .EXAMPLE
        Update-SEPMExceptionPolicy -PolicyName "Exception policy - Workstations" -LinuxExtensionException extension1, extension2 -SecurityRiskCategory ScheduledAndOndemand

        Excludes the extension1 and extension2 extensions from the ScheduledAndOndemand type of scan
    
    .EXAMPLE
        Update-SEPMExceptionPolicy -PolicyName "Workstations Exception Policy" -MacFileException -MacPath "/home/personal/myfile.pdf"

        Excludes the myfile.pdf file located in the /home/personal directory from all types of scans
    
    .EXAMPLE
        Update-SEPMExceptionPolicy -PolicyName "Workstations Exception Policy" -MacFileException -MacPath "/home/personal/myfile.pdf" -DeleteException

        Deletes the exception for the myfile.pdf file located in the /home/personal directory

    .EXAMPLE
        Update-SEPMExceptionPolicy -PolicyName "Exception policy - Workstations" -ApplicationToMonitorException -Name "myapp.exe"

        Adds the myapp.exe application to the list of applications to monitor

    .EXAMPLE
        Update-SEPMExceptionPolicy -PolicyName "Exception policy - Workstations" -LinuxFolderException -LinuxPath /home/user/myfolder -SecurityRiskCategory ScheduledAndOndemand 

        Adds the /home/user/myfolder folder to the list of folders to exclude from the ScheduledAndOndemand type of scan
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

        # Description
        [Parameter()]
        [String]
        $PolicyDescription,

        # Enabled Policy
        [Parameter()]
        [switch]
        $EnablePolicy,

        # Disable Policy
        [Parameter()]
        [switch]
        $DisablePolicy,

        # WindowsFileException
        [Parameter(ParameterSetName = 'WindowsFileException')]
        [switch]
        $WindowsFileException,

        # WindowsFolderException
        [Parameter(ParameterSetName = 'WindowsFolderException')]
        [switch]
        $WindowsFolderException,

        # Windows Extension Exception
        [Parameter(ParameterSetName = 'WindowsExtensionException')]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $WindowsExtensionException,

        # Mac File Exception
        [Parameter(ParameterSetName = 'MacFileException')]
        [switch]
        $MacFileException,

        # Linux Folder Exception
        [Parameter(ParameterSetName = 'LinuxFolderException')]
        [switch]
        $LinuxFolderException,

        # Linux Extension Exception
        [Parameter(ParameterSetName = 'LinuxExtensionException')]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $LinuxExtensionException,

        # Application to Monitor
        [Parameter(ParameterSetName = 'ApplicationToMonitorException')]
        [ValidateNotNullOrEmpty()]
        [switch]
        $ApplicationToMonitorException,

        # Application Name
        [Parameter(ParameterSetName = 'ApplicationToMonitorException', Mandatory = $true)]
        [Parameter(ParameterSetName = 'WebdomainException', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name,

        # Webdomain
        [Parameter(ParameterSetName = 'WebdomainException')]
        [ValidateNotNullOrEmpty()]
        [switch]
        $WebdomainException,

        # Sonar
        [Parameter(ParameterSetName = 'WindowsFileException')]
        [switch]
        $Sonar,

        # deleted
        [Parameter(ParameterSetName = 'WindowsFileException')]
        [Parameter(ParameterSetName = 'WindowsFolderException')]
        [Parameter(ParameterSetName = 'WindowsExtensionException')]
        [Parameter(ParameterSetName = 'MacFileException')]
        [Parameter(ParameterSetName = 'LinuxFolderException')]
        [Parameter(ParameterSetName = 'LinuxExtensionException')]
        [Parameter(ParameterSetName = 'ApplicationToMonitorException')]
        [Parameter(ParameterSetName = 'WebdomainException')]
        [switch]
        $DeleteException,

        # Looks like this is not used in SEPM
        # # RulestateEnabled
        # [Parameter(ParameterSetName = 'WindowsFileException')]
        # [Parameter(ParameterSetName = 'WindowsFolderException')]
        # [Parameter(ParameterSetName = 'MacFileException')]
        # [Alias('EnableRule')]
        # [switch]$RulestateEnabled,

        # # RulestateDisabled
        # [Parameter(ParameterSetName = 'WindowsFileException')]
        # [Parameter(ParameterSetName = 'WindowsFolderException')]
        # [Parameter(ParameterSetName = 'MacFileException')]
        # [Alias('DisableRuleState')]
        # [switch]$RulestateDisabled,

        # [Parameter(ParameterSetName = 'WindowsFileException')]
        # [Parameter(ParameterSetName = 'WindowsFolderException')]
        # [Parameter(ParameterSetName = 'MacFileException')]
        # [string] 
        # $RulestateSource = "PSSymantecSEPM",

        # Scancategory - requires securityrisk to be set to true
        [Parameter(ParameterSetName = 'WindowsFileException')]
        [Parameter(ParameterSetName = 'WindowsFolderException')]
        [Parameter(ParameterSetName = 'LinuxFolderException')]
        [Parameter(ParameterSetName = 'LinuxExtensionException')]
        [Parameter(ParameterSetName = 'WindowsExtensionException')]
        [ValidateSet(
            'AllScans',
            'AutoProtect',
            'ScheduledAndOndemand'
        )]
        [string] 
        $SecurityRiskCategory,

        # Pathvariable
        [Parameter(ParameterSetName = 'WindowsFileException')]
        [Parameter(ParameterSetName = 'WindowsFolderException')]
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

        # Mac Pathvariable
        [Parameter(ParameterSetName = 'MacFileException')]
        [ValidateSet(
            '[NONE]', 
            '[HOME]', 
            '[APPLICATION]', 
            '[LIBRARY ]'
        )]
        [string]
        $MacPathVariable = "[NONE]",

        # Linux Pathvariable
        [Parameter(ParameterSetName = 'LinuxFolderException')]
        [ValidateSet(
            '[NONE]', 
            '[HOME]', 
            '[ROOT]', 
            '[BIN]', 
            '[ETC]', 
            '[USR]', 
            '[OPT]'
        )]
        [string]
        $LinuxPathVariable = "[NONE]",

        # Path
        [Parameter(ParameterSetName = 'WindowsFileException', Mandatory = $true)]
        [Parameter(ParameterSetName = 'WindowsFolderException', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [Alias('WindowsPath')]
        [string] 
        $Path,

        # Mac Path
        [Parameter(ParameterSetName = 'MacFileException', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $MacPath,

        # Linux Path
        [Parameter(ParameterSetName = 'LinuxFolderException', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $LinuxPath,

        # Applicationcontrol
        [Parameter(ParameterSetName = 'WindowsFileException')]
        [switch]
        $ApplicationControl,

        # AllScans
        [Parameter(ParameterSetName = 'WindowsFileException')]
        [Parameter(ParameterSetName = 'WindowsFolderException')]
        [switch]
        $AllScans,

        # Recursive - requires applicationcontrol to be set to true
        [Parameter(ParameterSetName = 'WindowsFileException')]
        [switch]
        $ExcludeChildProcesses,

        # Recursive 
        [Parameter(ParameterSetName = 'WindowsFolderException')]
        [Parameter(ParameterSetName = 'LinuxFolderException')]
        [switch]
        $IncludeSubFolders,

        # ScanType 
        [Parameter(ParameterSetName = 'WindowsFolderException')]
        [ValidateSet(
            'SecurityRisk',
            'SONAR',
            'ApplicationControl',
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
        $policies = Get-SEPMPoliciesSummary

        # hardcode the RulestateSource to the module name
        $RulestateSource = "PSSymantecSEPM"
    }

    process {
        # Get Policy ID from policy name
        $PolicyID = $policies | Where-Object { $_.name -eq $PolicyName } | Select-Object -ExpandProperty id
        
        # Update URI with Policy ID
        $URI = $URI + "/" + $PolicyID

        # Instantiates the skeleton of the body structure to update the exception policy
        $ObjBody = [SEPMPolicyExceptionsStructure]::new()

        # Update the body structure with the mandatory parameters
        $ObjBody.name = $PolicyName

        # Init
        $ExceptionParams = @{}

        # Common parameters
        # Adding default values if not explicitely provided
        # As $PSBoundParameters.Keys doesn't contain default parameters values
        if ($pathvariable -eq "[NONE]") {
            $ExceptionParams.pathvariable = "[NONE]"
        }
        if ($RulestateSource -eq "PSSymantecSEPM") {
            $ExceptionParams.RulestateSource = "PSSymantecSEPM"
        }

        # Exception types are split in groups via switches
        # -WindowsFileException / -WindowsFolderException / etc...
        # Each switch contains the parameters specific to the exception type
        # The parameters are parsed and added to the $ExceptionParams hashtable

        # WindowsFileException
        if ($WindowsFileException) {
            # Parse the parameters provided
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
                "PathVariable" {
                    $ExceptionParams.pathvariable = $pathvariable
                }
                "Path" {
                    $ExceptionParams.path = $path
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
                }
            }

            # If no scan type is provided, default to AllScans
            if (-not $ExceptionParams.securityrisk -and -not $ExceptionParams.sonar -and -not $ExceptionParams.applicationcontrol) {
                $ExceptionParams.securityrisk = $true
                $ExceptionParams.sonar = $true
                $ExceptionParams.applicationcontrol = $true
            }

            # Create the file exception object with CreateFilesHashTable
            # Method parameters have to be in the same order as in the method definition
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

            # Add the file exception parameters to the body structure
            $ObjBody.AddConfigurationFilesExceptions($FilesHashTable)
        }

        # WindowsFolderException
        if ($WindowsFolderException) {
            switch ($PSBoundParameters.Keys) {
                "DeleteException" {
                    $ExceptionParams.deleted = $true
                }
                "SecurityRiskCategory" {
                    # SecurityRiskCategory can only be used if the ScanType parameter is 'SecurityRisk'
                    if ($ScanType -eq 'SecurityRisk') {
                        $ExceptionParams.scancategory = $SecurityRiskCategory
                    } else {
                        throw "The SecurityRiskCategory parameter can only be used if the ScanType parameter is 'SecurityRisk'"
                    }
                }
                "ScanType" {
                    $ExceptionParams.scantype = $ScanType
                }
                "PathVariable" {
                    $ExceptionParams.pathvariable = $pathvariable
                }
                "Path" {
                    $ExceptionParams.directory = $path
                }
                "IncludeSubFolders" {
                    $ExceptionParams.recursive = $true
                }
                "AllScans" {
                    $ExceptionParams.scancategory = "AllScans"
                    $ExceptionParams.scantype = "All"
                }
            }

            # If no scan type is provided, default to AllScans
            if (-not $ExceptionParams.scancategory -and -not $ExceptionParams.scantype) {
                $ExceptionParams.scancategory = "AllScans"
                $ExceptionParams.scantype = "All"
            }

            # Create folder exception object with CreateDirectoryHashtable
            # Method parameters have to be in the same order as in the method definition
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

            # Add the folder exception parameters to the body structure
            $ObjBody.AddConfigurationDirectoriesExceptions($DirectoryHashTable)
        }

        # WindowsExtensionException
        if ($WindowsExtensionException) {
            switch ($PSBoundParameters.Keys) {
                "DeleteException" {
                    $ExceptionParams.deleted = $true
                }
                "WindowsExtensionException" {
                    $extensionList = @()
                    foreach ($extension in $WindowsExtensionException) {
                        $extensionList += $extension
                    }
                    $ExceptionParams.extensions = $extensionList
                }
                "SecurityRiskCategory" {
                    $ExceptionParams.scancategory = $SecurityRiskCategory
                }
            }

            # If no scan type is provided, default to AllScans
            if (-not $ExceptionParams.scancategory) {
                $ExceptionParams.scancategory = "AllScans"
            }

            # Create extension exception object with CreateExtensionHashtable
            # Method parameters have to be in the same order as in the method definition
            $ExtensionHashTable = $ObjBody.CreateExtensionListHashtable(
                $ExceptionParams.deleted,
                $ExceptionParams.RulestateEnabled,
                $RulestateSource,
                $ExceptionParams.scancategory,
                $ExceptionParams.extensions
            )

            # Add the extension exception parameters to the body structure
            $ObjBody.AddExtensionsList($ExtensionHashTable)
        }

        # MacFileException
        if ($MacFileException) {
            # TODO update mac for SONAR and SecurityRisk both in function and class
            # Exception GUI shows SONAR & SecurityRisk as options but not the API
            switch ($PSBoundParameters.Keys) {
                "DeleteException" {
                    $ExceptionParams.deleted = $true
                }
                "MacPathVariable" {
                    $ExceptionParams.pathvariable = $MacPathVariable
                }
                "MacPath" {
                    $ExceptionParams.path = $MacPath
                }
            }

            # Create the file exception object with CreateFilesHashTable
            # Method parameters have to be in the same order as in the method definition
            $MacFilesHashTable = $ObjBody.CreateMacFilesHashtable(
                $ExceptionParams.deleted,
                $ExceptionParams.RulestateEnabled,
                $RulestateSource,
                $ExceptionParams.pathvariable,
                $ExceptionParams.path
            )

            # Add the file exception parameters to the body structure
            $ObjBody.AddMacFiles($MacFilesHashTable)
        }

        # LinuxFolderException
        if ($LinuxFolderException) {
            switch ($PSBoundParameters.Keys) {
                "DeleteException" {
                    $ExceptionParams.deleted = $true
                }
                "SecurityRiskCategory" {
                    $ExceptionParams.securityrisk = $true
                    $ExceptionParams.scancategory = $SecurityRiskCategory
                }
                "LinuxPathVariable" {
                    $ExceptionParams.pathvariable = $LinuxPathVariable
                }
                "LinuxPath" {
                    $ExceptionParams.directory = $LinuxPath
                }
                "IncludeSubFolders" {
                    $ExceptionParams.recursive = $true
                }
                
            }

            # Create folder exception object with CreateDirectoryHashtable
            # Method parameters have to be in the same order as in the method definition
            $LinuxDirectoryHashTable = $ObjBody.CreateLinuxDirectoryHashtable(
                $ExceptionParams.deleted,
                $ExceptionParams.RulestateEnabled,
                $RulestateSource,
                $ExceptionParams.scancategory,
                $ExceptionParams.pathvariable,
                $ExceptionParams.directory,
                $ExceptionParams.recursive
            )

            # Add the folder exception parameters to the body structure
            $ObjBody.AddLinuxDirectory($LinuxDirectoryHashTable)
        }

        # LinuxExtensionException
        if ($LinuxExtensionException) {
            switch ($PSBoundParameters.Keys) {
                "DeleteException" {
                    $ExceptionParams.deleted = $true
                }
                "LinuxExtensionException" {
                    $extensionList = @()
                    foreach ($extension in $LinuxExtensionException) {
                        $extensionList += $extension
                    }
                    $ExceptionParams.extensions = $extensionList
                }
                # TODO add scan type for LinuxExtensionException
                "SecurityRiskCategory" {
                    $ExceptionParams.scancategory = $SecurityRiskCategory
                }
            }

            # If no scan type is provided, default to AllScans
            if (-not $ExceptionParams.scancategory) {
                $ExceptionParams.scancategory = "AllScans"
            }

            # Create extension exception object with CreateExtensionHashtable
            # Method parameters have to be in the same order as in the method definition
            $LinuxExtensionHashTable = $ObjBody.CreateLinuxExtensionListHashtable(
                $ExceptionParams.deleted,
                $ExceptionParams.RulestateEnabled,
                $RulestateSource,
                $ExceptionParams.scancategory,
                $ExceptionParams.extensions
            )

            # Add the extension exception parameters to the body structure
            $ObjBody.AddLinuxExtensionList($LinuxExtensionHashTable)
        }

        # ApplicationToMonitorException
        if ($ApplicationToMonitorException) {
            switch ($PSBoundParameters.Keys) {
                "DeleteException" {
                    $ExceptionParams.deleted = $true
                }
                "Name" {
                    $ExceptionParams.name = $Name
                }
            }

            # Create application exception object with CreateApplicationHashtable
            # Method parameters have to be in the same order as in the method definition
            $ApplicationHashTable = $ObjBody.CreateApplicationsToMonitorHashtable(
                $ExceptionParams.deleted,
                $ExceptionParams.RulestateEnabled,
                $RulestateSource,
                $ExceptionParams.name
            )

            # Add the application exception parameters to the body structure
            $ObjBody.AddApplicationsToMonitor($ApplicationHashTable)
        }

        # WebdomainException
        if ($WebdomainException) {
            switch ($PSBoundParameters.Keys) {
                "DeleteException" {
                    $ExceptionParams.deleted = $true
                }
                "Name" {
                    $ExceptionParams.name = $Name
                }
            }

            # Create application exception object with CreateApplicationHashtable
            # Method parameters have to be in the same order as in the method definition
            $WebdomainHashTable = $ObjBody.CreateWebdomainsHashtable(
                $ExceptionParams.deleted,
                $ExceptionParams.RulestateEnabled,
                $RulestateSource,
                $ExceptionParams.name
            )

            # Add the application exception parameters to the body structure
            $ObjBody.AddWebdomains($WebdomainHashTable)
        }

        # Common parameters
        # Verify if updates to the policy are needed
        switch ($psboundparameters.Keys) {
            "EnablePolicy" {
                $ObjBody.enabled = $true
            }
            "DisablePolicy" {
                $ObjBody.enabled = $false
            }
            "Description" {
                $ObjBody.desc = $PolicyDescription
            }

        }

        # Optimize the body structure (remove empty properties)
        $ObjBody = Optimize-ExceptionPolicyStructure -obj $ObjBody

        # TODO For testing only - remove this
        # $ObjBody | ConvertTo-Json -Depth 100 | Out-File .\Data\PolicyStructure.json -Force

        # prepare the parameters
        $params = @{
            Method      = 'PATCH'
            Uri         = $URI
            headers     = $headers
            contenttype = 'application/json'
            Body        = $ObjBody | ConvertTo-Json -Depth 100
        }

        $resp = Invoke-ABRestMethod -params $params
        return $resp
    }
}