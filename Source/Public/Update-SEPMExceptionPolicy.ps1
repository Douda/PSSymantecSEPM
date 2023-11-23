function Update-SEPMExceptionPolicy {
    <# TODO Update the help information
    .SYNOPSIS
        A short one-line action-based description, e.g. 'Tests if a function is valid'
    .DESCRIPTION
        A longer description of the function, its purpose, common use cases, etc.
    .NOTES
        Information or caveats about the function e.g. 'This function is not supported in Linux'
    .LINK
        Specify a URI to a help page, this will show when Get-Help -Online is used.
    .EXAMPLE
        Test-MyTestFunction -Verbose
        Explanation of the function or its result. You can include multiple examples with additional .EXAMPLE lines
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
        # [Alias('PolicyDescription')]
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

        # Exception type
        [Parameter(
            Mandatory = $true
        )]
        [ValidateSet(
            'WindowsFileException',
            'WindowsFolderException'
        )]
        [string]
        $ExceptionType,

        # Sonar
        [Parameter(ParameterSetName = 'ByFileException')]
        [switch]
        $Sonar,

        # deleted
        [Parameter(ParameterSetName = 'ByFileException')]
        [switch]
        $DeleteException,

        # Looks like this is not used in SEPM
        # Rulestate_enabled
        [Parameter(ParameterSetName = 'ByFileException')]
        [Alias('EnableRuleState')]
        [bool]$rulestate_enabled,

        [Parameter(ParameterSetName = 'ByFileException')]
        [string] 
        $Rulestate_Source = "PSSymantecSEPM",

        # Scancategory - requires securityrisk to be set to true
        [Parameter(ParameterSetName = 'ByFileException')]
        [ValidateSet(
            'AllScans',
            'Auto-Protect',
            'ScheduledAndOndemand'
        )]
        [string] 
        $SecurityRiskCategory,

        # Pathvariable
        [Parameter(ParameterSetName = 'ByFileException')]
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
        [Parameter(ParameterSetName = 'ByFileException')]
        [string] 
        $Path,

        # Applicationcontrol
        [Parameter(ParameterSetName = 'ByFileException')]
        [switch]
        $ApplicationControl,

        # AllScans
        [Parameter(ParameterSetName = 'ByFileException')]
        [switch]
        $AllScans,

        # Recursive - requires applicationcontrol to be set to true
        [Parameter(ParameterSetName = 'ByFileException')]
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
        $policies = Get-SEPMPoliciesSummary
    }

    process {
        # Get Policy ID from policy name
        $PolicyID = $policies | Where-Object { $_.name -eq $PolicyName } | Select-Object -ExpandProperty id
        # Update URI with Policy ID
        $URI = $URI + "/" + $PolicyID

        # Get the skeleton of the body structure to update the exception policy
        $PolicyStructure = [SEPMPolicyExceptionsStructure]::new()

        # Update the body structure with the mandatory parameters
        $PolicyStructure.name = $PolicyName

        # Init
        $ExceptionParams = @{}

        # Check the exception type
        # Then group parameters in hashtable
        switch ($ExceptionType) {
            "WindowsFileException" {
                # Parse the parameters provided
                switch ($PSBoundParameters.Keys) {
                    "Sonar" {
                        $ExceptionParams.sonar = $true
                    }
                    "DeleteException" {
                        $ExceptionParams.deleted = $true
                    }
                    # Looks like this is not used in SEPM
                    # TODO verify this
                    "rulestate_enabled" {
                        $ExceptionParams.rulestate_enabled = $true
                    }
                    "Rulestate_Source" {
                        $ExceptionParams.rulestate_source = $rulestate_source
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

                # Adding default values if not explicitely provided provided
                # As $PSBoundParameters.Keys doesn't contain default parameters values
                if ($pathvariable -eq "[NONE]") {
                    $ExceptionParams.pathvariable = "[NONE]"
                }
                if ($RuleState_source -eq "PSSymantecSEPM") {
                    $ExceptionParams.rulestate_source = "PSSymantecSEPM"
                }

                # Create the file exception object with CreateFilesHashTable
                # Method parameters have to be in the same order as in the method definition
                $FilesHashTable = $PolicyStructure.CreateFilesHashTable(
                    $ExceptionParams.sonar,
                    $ExceptionParams.deleted,
                    $ExceptionParams.rulestate_enabled,
                    $ExceptionParams.rulestate_source,
                    $ExceptionParams.scancategory,
                    $ExceptionParams.pathvariable,
                    $ExceptionParams.path,
                    $ExceptionParams.applicationcontrol,
                    $ExceptionParams.securityrisk,
                    $ExceptionParams.recursive
                )

                # Add the file exception parameters to the body structure
                $PolicyStructure.AddConfigurationFilesExceptions($FilesHashTable)
            }
            "WindowsFolderException" {
                # TODO implement this
                # TODO add new parameterset for folder exception
            }
        }

        # Verify if updates to the policy are needed
        switch ($psboundparameters.Keys) {
            "EnablePolicy" {
                $PolicyStructure.enabled = $true
            }
            "DisablePolicy" {
                $PolicyStructure.enabled = $false
            }
            "Description" {
                $PolicyStructure.desc = $PolicyDescription
            }
        }

        # Optimize the body structure (remove empty properties)
        $PolicyStructure = Optimize-ExceptionPolicyStructure -obj $PolicyStructure

        # For testing only
        # TODO remove this
        $PolicyStructure | ConvertTo-Json -Depth 100 | Out-File .\Data\PolicyStructure.json -Force

        # TODO remove hardcoded information
        # Body
        # $body = @{
        #     # "desc"          = $PolicyDescription
        #     "name"          = $PolicyName
        #     # "enabled" = $Enabled
        #     "configuration" = @{
        #         "files" = @(
        #             @{
        #                 "sonar"        = $true
        #                 "pathvariable" = "[NONE]"
        #                 "path"         = "C:\Temp\Aurelien.exe"
        #                 "rulestate"    = @{
        #                     "enabled" = $true
        #                     "source"  = "PSSymantecSEPM"
        #                 }
        #             }
        #         )
        #     }
        # }

        # # prepare the parameters
        # $params = @{
        #     Method      = 'PATCH'
        #     Uri         = $URI
        #     headers     = $headers
        #     contenttype = 'application/json'
        #     Body        = $body | ConvertTo-Json -Depth 100
        # }

        # try {
        #     $resp = Invoke-ABRestMethod -params $params
        # } catch {
        #     Write-Warning -Message "Error: $_"
        # }

        # return $resp
    }
}