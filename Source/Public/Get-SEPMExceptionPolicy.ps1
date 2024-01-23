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
    .PARAMETER SkipCertificateCheck
        Skip certificate check
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

    [CmdletBinding()]
    Param (
        # PolicyName
        [Parameter(
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Mandatory = $true
        )]
        [Alias("Policy_Name")]
        [String]
        $PolicyName,

        # Skip certificate check
        [Parameter()]
        [switch]
        $SkipCertificateCheck,

        # List a specific exception category
        [Parameter()]
        [ValidateSet("files", "directories", "webdomains", "extensions")]
        [String]
        $List
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
        # BaseURL V2
        $URI = $script:BaseURLv2 + "/policies/exceptions"
        $headers = @{
            "Authorization" = "Bearer " + $script:accessToken.token
            "Content"       = 'application/json'
        }
        # Stores the policy summary for all policies only once
        $policies = Get-SEPMPoliciesSummary
    }

    process {
        # Get Policy ID from policy name
        $policyID = $policies | Where-Object { $_.name -eq $PolicyName } | Select-Object -ExpandProperty id
        $policy_type = $policies | Where-Object { $_.name -eq $PolicyName } | Select-Object -ExpandProperty policytype

        if ($policy_type -ne "exceptions") {
            $message = "policy type is not of type EXCEPTIONS or does not exist - Please verify the policy name"
            Write-Error -Message $message
            throw $message
        }

        # Updating URI with policy ID
        $URI = $URI + "/" + $policyID
        
        # prepare the parameters
        $params = @{
            Method          = 'GET'
            Uri             = $URI
            headers         = $headers
            UseBasicParsing = $true
        }
    
        $resp = Invoke-ABRestMethod -params $params
        
        # JSON response to convert to PSObject
        $resp = $resp | ConvertFrom-Json -AsHashtable -Depth 100
        
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
                foreach ($f in $resp.configuration.files) {
                    $f["Platform"] = "Windows"
                    $files += $f
                }

                # Add the Mac platform to the files
                foreach ($f in $resp.configuration.mac.files) {
                    $f["Platform"] = "Mac"
                    $files += $f
                }

                # TODO : 01/23/2024 -  Linux file exception is not a supported exception type in SEPM
                # Add the Linux platform to the files
                # foreach ($f in $resp.configuration.linux.files) {
                #     $f["Platform"] = "Linux"
                #     $files += $f
                # }

                return $files | ConvertTo-FlatObject
            }
            "directories" {
                $directories = @()
                # Add the Windows platform to the directories
                foreach ($d in $resp.configuration.directories) {
                    $d["Platform"] = "Windows"
                    $directories += $d
                }

                # TODO : 01/23/2024 - Mac directory exception is not a supported exception type in SEPM
                # Add the Mac platform to the directories
                # foreach ($d in $resp.configuration.mac.directories) {
                #     $d["Platform"] = "Mac"
                #     $directories += $d
                # }

                # Add the Linux platform to the directories
                foreach ($d in $resp.configuration.linux.directories) {
                    $d["Platform"] = "Linux"
                    $directories += $d
                }

                return $directories | ConvertTo-FlatObject
            }
            "webdomains" {
                return $resp.configuration.webdomains | ConvertTo-FlatObject
            }
            "extensions" {
                $extensions = @()
                # Add the Windows platform to the extensions
                foreach ($e in $resp.configuration.extension_list) {
                    $e["Platform"] = "Windows"
                    $extensions += $e
                }

                # Add the Linux platform to the extensions
                foreach ($e in $resp.configuration.linux.extension_list) {
                    $e["Platform"] = "Linux"
                    $extensions += $e
                }

                return $extensions | ConvertTo-FlatObject
            }
            Default { return $resp }
        }
        
    }
}