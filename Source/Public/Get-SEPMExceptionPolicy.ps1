function Get-SEPMExceptionPolicy {
    <#
    .SYNOPSIS
        Get Exception Policy
    .DESCRIPTION
        Get Exception Policy details
        Note this is a V2 API call, and replies are originally JSON based
    .PARAMETER PolicyName    
        The name of the policy to get the details of
        Is a required parameter
    .PARAMETER List
        List a specific exception category
        Valid values are "files", "directories", "webdomains"
        # TODO : add all the other exception types in example
    .PARAMETER PolicyList
        Optional array of policy summary objects (from Get-SEPMPoliciesSummary).
        When provided with -PolicyName, skips the internal Get-SEPMPoliciesSummary
        call and resolves the policy ID from this list instead.
    .EXAMPLE
        PS C:\PSSymantecSEPM> Get-SEPMExceptionPolicy -PolicyName "Standard Servers - Exception policy"

        Name                           Value
        ----                           -----
        sources                        {}
        configuration                  {[files, System.Object[]], [non_pe_rules, System.Object[]], [directories, System.Object[]], [webdomains, System.Object[]]…}
        lockedoptions                  {[knownrisk, True], [extension, True], [file, True], [domain, True]…}
        enabled                        True
        desc
        name                           Standard Servers - Exception policy
        lastmodifiedtime               1646398353107

        Shows an example of getting the Exception policy details for the policy named "Workstations Exception Policy
    .EXAMPLE
        PS C:\PSSymantecSEPM> Get-SEPMExceptionPolicy -PolicyName "AB - Testing - API" -List files | Format-Table

        SONAR rulestate.enabled rulestate.source scancategory pathvariable path                                        applicationcontrol securityrisk recursive Platform
        ----- ----------------- ---------------- ------------ ------------ ----                                        ------------------ ------------ --------- --------
        False               True PSSymantecSEPM   AutoProtect  [NONE]       C:\Temp\File5.exe                                        False         True     False Windows
        True                True PSSymantecSEPM   AutoProtect  [NONE]       C:\Temp\File.exe                                          True         True     False Windows
                            True                               [NONE]       /applications/test/SONAR                                                              Mac
                            True                               [NONE]       /Applications/test/TestFolder                                                         Mac

        Gets Exception details for the policy named "Workstations Exception Policy" and listing only the files exceptions
    .EXAMPLE
        PS C:\PSSymantecSEPM> Get-SEPMExceptionPolicy -PolicyName "AB - Testing - API" -List directories | Format-Table

        rulestate.enabled scancategory scantype           pathvariable directory                                   recursive Platform
        ----------------- ------------ --------           ------------ ---------                                   --------- --------
                    True AutoProtect  SecurityRisk       [NONE]       C:\Temp\SecurityRiskAP\                         False Windows
                    True AllScans     SONAR              [NONE]       C:\Temp\SonarWithSubfolders\                     True Windows
                    True AllScans     ApplicationControl [NONE]       C:\Temp\AppControlException\                     True Windows
                    True AllScans     All                [NONE]       C:\Temp\FolderWithSubfoldersAllScans\            True Windows
                    True AllScans                        [NONE]       /home/user1/ExcludedFolderWithSubfolders         True Linux

        Gets Exception details for the policy named "Workstations Exception Policy" and listing only the directories exceptions
    .EXAMPLE
        PS C:\PSSymantecSEPM> Get-SEPMExceptionPolicy -PolicyName "AB - Testing - API" -List webdomains | Format-Table

        rulestate.enabled rulestate.source domain
        ----------------- ---------------- ------
                    True PSSymantecSEPM   HTTPS://test.com
                    True                  HTTP://test.com
                    True PSSymantecSEPM   HTTP://8.8.8.8
            
        Gets Exception details for the policy named "Workstations Exception Policy" and listing only the webdomains exceptions
    .EXAMPLE
        PS C:\PSSymantecSEPM> Get-SEPMExceptionPolicy -PolicyName "Workstations Exception Policy" -List extensions | Format-Table

        rulestate.enabled scancategory extensions.1    extensions.2    Platform
        ----------------- ------------ ------------    ------------    --------
                    True AllScans     tmp             extension2      Windows
                    True AutoProtect  dk.tmp          extension2      Linux
#>

    [CmdletBinding(DefaultParameterSetName = 'ByName')]
    Param (
        # PolicyName
        [Parameter(
            ParameterSetName = 'ByName',
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Mandatory = $true
        )]
        [Alias("Policy_Name")]
        [String]
        $PolicyName,

        # PolicySummary
        [Parameter(
            ParameterSetName = 'BySummary',
            Mandatory = $true
        )]
        [PSCustomObject]
        $PolicySummary,

        # List a specific exception category
        [Parameter()]
        [ValidateSet("files", "directories", "webdomains", "extensions", "tamper")]
        [String]
        $List,

        # Pre-fetched policy list from Get-SEPMPoliciesSummary. When provided, skips the
        # internal Get-SEPMPoliciesSummary call, avoiding a redundant API round-trip.
        [Parameter()]
        [object[]]
        $PolicyList
    )

    begin {
        $session = Initialize-SEPMSession
        $endpoint = Get-SEPMApiEndpoint -OperationName 'Get-SEPMExceptionPolicy'

    }

    process {
        if ($PSCmdlet.ParameterSetName -eq 'ByName') {
            $splat = @{
                PolicyName = $PolicyName
                PolicyType = 'exceptions'
            }
            if ($PSBoundParameters.ContainsKey('PolicyList')) {
                $splat.PolicyList = $PolicyList
            }
            $policyID = Resolve-SEPMPolicy @splat
        } else {
            $policyID = $PolicySummary.id
            $policy_type = $PolicySummary.policytype
            if ($policy_type -ne "exceptions") {
                $message = "policy type is not of type EXCEPTIONS or does not exist - Please verify the policy name"
                Write-Error -Message $message
                throw $message
            }
        }

        $resp = Invoke-SepmEndpoint -Endpoint $endpoint -Session $session -PathIds @($policyID)

        # Add a PSTypeName to the object
        $resp.PSObject.TypeNames.Insert(0, 'SEPM.ExceptionPolicy')

        # Access the ScriptProperties of 'SEPM.ExceptionPolicy' to force them to run at least once
        # This is to ensure that the properties are available when the object is returned
        # refer to PSType SEPM.ExceptionPolicy for more details
        $null = $resp.lastModifiedTimeDate

        # If a specific list is requested, return only that list
        switch ($List) {
            "files" {
                $files = @()
                # Add the Windows platform to the files
                if ($null -ne $resp.configuration.files) {
                    foreach ($f in $resp.configuration.files) {
                        $f["Platform"] = "Windows"
                        $files += $f
                    }
                }

                # Add the Mac platform to the files
                if ($null -ne $resp.configuration.mac.files) {
                    foreach ($f in $resp.configuration.mac.files) {
                        $f["Platform"] = "Mac"
                        $files += $f
                    }
                }

                # TODO : 01/23/2024 -  Linux file exception is not a supported exception type in SEPM
                # Add the Linux platform to the files
                # if ($null -ne $resp.configuration.linux.files) {
                #     foreach ($f in $resp.configuration.linux.files) {
                #         $f["Platform"] = "Linux"
                #         $files += $f
                #     }
                # }

                if ($files.Count -eq 0) {
                    Write-Output @() -NoEnumerate
                } else {
                    $result = $files | ConvertTo-SEPMFlatObject
                    Write-Output $result -NoEnumerate
                }
            }
            "directories" {
                $directories = @()
                # Add the Windows platform to the directories
                foreach ($d in $resp.configuration.directories) {
                    $d["Platform"] = "Windows"
                    $directories += $d
                }

                # Add the Linux platform to the directories
                if ($null -ne $resp.configuration.linux.directories) {
                    foreach ($d in $resp.configuration.linux.directories) {
                        $d["Platform"] = "Linux"
                        $directories += $d
                    }
                }

                if ($directories.Count -eq 0) {
                    # Empty result on PS 5.1: ConvertTo-SEPMFlatObject may throw on empty
                    # hashtable-based arrays (ConvertTo-Hashtable data shape).
                    Write-Output @() -NoEnumerate
                } else {
                    $result = $directories | ConvertTo-SEPMFlatObject
                    Write-Output $result -NoEnumerate
                }
            }
            "webdomains" {
                $result = $resp.configuration.webdomains | ConvertTo-SEPMFlatObject
                if ($result -is [array]) {
                    Write-Output $result -NoEnumerate
                } else {
                    $result
                }
            }
            "extensions" {
                $extensions = @()
                # Add the Windows platform to the extensions
                if ($null -ne $resp.configuration.extension_list) {
                    foreach ($e in $resp.configuration.extension_list) {
                        $e["Platform"] = "Windows"
                        $extensions += $e
                    }
                }

                # Add the Linux platform to the extensions
                if ($null -ne $resp.configuration.linux.extension_list) {
                    foreach ($e in $resp.configuration.linux.extension_list) {
                        $e["Platform"] = "Linux"
                        $extensions += $e
                    }
                }

                if ($extensions.Count -eq 0) {
                    Write-Output @() -NoEnumerate
                } else {
                    $result = $extensions | ConvertTo-SEPMFlatObject
                    Write-Output $result -NoEnumerate
                }
            }
            "tamper" {
                $result = $resp.configuration.tamper_files | ConvertTo-SEPMFlatObject
                if ($result -is [array]) {
                    Write-Output $result -NoEnumerate
                } else {
                    $result
                }
            }
            Default { return $resp }
        }
    }
}
