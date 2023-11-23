
<# 
Class to manage exceptions policy. 
Create a policy exceptions object and add exception types to it with custom methods
Structure follows the API documentation : https://apidocs.securitycloud.symantec.com/#/doc?id=policies
Section : Update Exceptions Policy
#>
class SEPMPolicyExceptionsStructure {
    <# Define the class. Try constructors, properties, or methods. #>
    [object] $configuration
    [object] $lockedoptions
    [Nullable[bool]] $enabled
    [string] $desc
    [string] $name
    SEPMPolicyExceptionsStructure() {
        $this.configuration = [object]@{
            files                      = [System.Collections.Generic.List[object]]::new()
            non_pe_rules               = [System.Collections.Generic.List[object]]::new()
            directories                = [System.Collections.Generic.List[object]]::new()
            webdomains                 = [System.Collections.Generic.List[object]]::new()
            certificates               = [System.Collections.Generic.List[object]]::new()
            applications               = [System.Collections.Generic.List[object]]::new()
            denylistrules              = [System.Collections.Generic.List[object]]::new()
            applications_to_monitor    = [System.Collections.Generic.List[object]]::new()
            mac                        = [object]@{
                files = [System.Collections.Generic.List[object]]::new()
            }
            linux                      = [object]@{
                directories    = [System.Collections.Generic.List[object]]::new()
                extension_list = [object]::new()
            }
            extension_list             = [object]@{
                deleted      = $null
                rulestate    = [object]@{
                    enabled = $null
                    source  = $null
                }
                scancategory = $null
                extensions   = [System.Collections.Generic.List[object]]::new()
            }
            knownrisks                 = [System.Collections.Generic.List[object]]::new()
            tamper_files               = [System.Collections.Generic.List[object]]::new()
            dns_and_host_applications  = [System.Collections.Generic.List[object]]::new()
            dns_and_host_denylistrules = [System.Collections.Generic.List[object]]::new()
        }
        # $this.lockedoptions = [object]@{
        #     knownrisks   = $null
        #     extension    = $null
        #     file         = $null
        #     domain       = $null
        #     securityrisk = $null
        #     sonar        = $null
        #     application  = $null
        #     dnshostfile  = $null
        #     certificate  = $null
        # }
        $this.lockedoptions = [object]@{}
    }

    # Method to Update lockedoptions object
    [void] UpdateLockedOptions(
        [Nullable[bool]] $knownrisks = $null,
        [Nullable[bool]] $extension = $null,
        [Nullable[bool]] $file = $null,
        [Nullable[bool]] $domain = $null,
        [Nullable[bool]] $securityrisk = $null,
        [Nullable[bool]] $sonar = $null,
        [Nullable[bool]] $application = $null,
        [Nullable[bool]] $dnshostfile = $null,
        [Nullable[bool]] $certificate = $null
    ) {
        # Add key/value pairs to the hashtable only if the value is not $null or empty
        if ($null -ne $knownrisks) { $this.lockedoptions.knownrisks = $knownrisks }
        if ($null -ne $extension) { $this.lockedoptions.extension = $extension }
        if ($null -ne $file) { $this.lockedoptions.file = $file }
        if ($null -ne $domain) { $this.lockedoptions.domain = $domain }
        if ($null -ne $securityrisk) { $this.lockedoptions.securityrisk = $securityrisk }
        if ($null -ne $sonar) { $this.lockedoptions.sonar = $sonar }
        if ($null -ne $application) { $this.lockedoptions.application = $application }
        if ($null -ne $dnshostfile) { $this.lockedoptions.dnshostfile = $dnshostfile }
        if ($null -ne $certificate) { $this.lockedoptions.certificate = $certificate }
    }

    # Method to add description
    [void] AddDescription(
        [string] $description
    ) {
        $this.desc = $description
    }

    # Method to create a file hashtable
    [hashtable] CreateFilesHashTable(
        [Nullable[bool]] $sonar = $null,
        [Nullable[bool]] $deleted = $null,
        [Nullable[bool]] $rulestate_enabled = $null,
        [string] $rulestate_source = "PSSymantecSEPM",
        [string] $scancategory = "",
        [string] $pathvariable = "",
        [string] $path = "",
        [Nullable[bool]] $applicationcontrol = $null,
        [Nullable[bool]] $securityrisk = $null,
        [Nullable[bool]] $recursive = $null
    ) {
        # Create an empty hashtable
        $hashTable = @{}

        # Add key/value pairs to the hashtable only if the value is not $null or empty
        if ($null -ne $sonar) { $hashTable['sonar'] = $sonar }
        if ($null -ne $deleted) { $hashTable['deleted'] = $deleted }
        if (![string]::IsNullOrEmpty($scancategory)) { $hashTable['scancategory'] = $scancategory }
        if (![string]::IsNullOrEmpty($pathvariable)) { $hashTable['pathvariable'] = $pathvariable }
        if (![string]::IsNullOrEmpty($path)) { $hashTable['path'] = $path }
        if ($null -ne $applicationcontrol) { $hashTable['applicationcontrol'] = $applicationcontrol }
        if ($null -ne $securityrisk) { $hashTable['securityrisk'] = $securityrisk }
        if ($null -ne $recursive) { $hashTable['recursive'] = $recursive }

        # Create an empty hashtable for 'rulestate'
        $rulestate = @{}

        # Add 'enabled' to 'rulestate' only if it's not $null
        if ($null -ne $rulestate_enabled) {
            $rulestate['enabled'] = $rulestate_enabled
        }

        # Add 'source' to 'rulestate' only if it's not $null or empty
        if (![string]::IsNullOrEmpty($rulestate_source)) {
            $rulestate['source'] = $rulestate_source
        }

        # Add 'rulestate' to the main hashtable only if it's not empty
        if ($rulestate.Count -gt 0) {
            $hashTable['rulestate'] = [PSCustomObject]$rulestate
        }

        return $hashTable
    }

    # Method to add files exceptions
    [void] AddConfigurationFilesExceptions(
        [hashtable] $file # Use CreateFilesHashTable method
    ) {
        $this.configuration.files.Add($file)
    }

    # Method to create a file hashtable
    [hashtable] CreateNonPEFilesHashTable(
        [Nullable[bool]] $deleted = $null,
        [Nullable[bool]] $rulestate_enabled = $null,
        [string] $rulestate_source = "PSSymantecSEPM",
        [string] $file_sha2 = "",
        [string] $file_md5 = "",
        [string] $file_name = "",
        [string] $file_company = "",
        [Nullable[Int64]] $file_size = $null,
        [string] $file_description = "",
        [string] $file_directory = "",
        [string] $action = "",
        [string] $actor_sha2 = "",
        [string] $actor_md5 = "",
        [string] $actor_name = "",
        [string] $actor_company = "",
        [Nullable[Int64]] $actor_size = $null,
        [string] $actor_description = "",
        [string] $actor_directory = ""

    ) {
        return @{
            deleted   = $deleted
            rulestate = [PSCustomObject]@{
                enabled = $rulestate_enabled
                source  = $rulestate_source
            }
            file      = [PSCustomObject]@{
                sha2        = $file_sha2
                md5         = $file_md5
                name        = $file_name
                company     = $file_company
                size        = $file_size
                description = $file_description
                directory   = $file_directory
            }
            action    = $action
            actor     = [PSCustomObject]@{
                sha2        = $actor_sha2
                md5         = $actor_md5
                name        = $actor_name
                company     = $actor_company
                size        = $actor_size
                description = $actor_description
                directory   = $actor_directory
            }
        }
    }

    # Method to add non PE files exceptions
    [void] AddConfigurationNonPEFilesExceptions(
        [hashtable] $non_pe_file # Use CreateNonPEFilesHashTable method
    ) {
        $this.configuration.non_pe_rules.Add($non_pe_file)
    }

    # Method to create a directory hashtable
    [hashtable] CreateDirectoryHashtable(
        [Nullable[bool]] $deleted = $null,
        [Nullable[bool]] $rulestate_enabled = $null,
        [string] $rulestate_source = "PSSymantecSEPM",
        [string] $scancategory = "",
        [string] $scantype = "",
        [string] $pathvariable = "",
        [string] $directory = "",
        [Nullable[bool]] $recursive = $null
    ) {
        return @{
            deleted      = $deleted
            rulestate    = [PSCustomObject]@{
                enabled = $rulestate_enabled
                source  = $rulestate_source
            }
            scancategory = $scancategory
            scantype     = $scantype
            pathvariable = $pathvariable
            path         = $directory
            recursive    = $recursive
        }
    }

    # Method to add directories
    [void] AddDirectory(
        [hashtable] $directory # Use CreateDirectoryHashtable method
    ) {
        $this.configuration.directories.Add($directory)
    }
    
    # Method to create a webdomains hashtable
    [hashtable] CreateWebdomainsHashtable(
        [Nullable[bool]] $deleted = $null,
        [Nullable[bool]] $rulestate_enabled = $null,
        [string] $rulestate_source = "PSSymantecSEPM",
        [string] $domain = ""
    ) {
        return @{
            deleted   = $deleted
            rulestate = [PSCustomObject]@{
                enabled = $rulestate_enabled
                source  = $rulestate_source
            }
            domain    = $domain
        }
    }

    # Method to add webdomains
    [void] AddWebdomains(
        [hashtable] $webdomains # Use CreateWebdomainsHashtable method
    ) {
        $this.configuration.webdomains.Add($webdomains)
    }

    # Method to create a certificate hashtable
    [hashtable] CreateCertificatesHashtable(
        [Nullable[bool]] $deleted = $null,
        [Nullable[bool]] $rulestate_enabled = $null,
        [string] $rulestate_source = "PSSymantecSEPM",
        [string] $signature_fingerprint_algorith = "",
        [string] $signature_fingerprint_value = "",
        [string] $signature_company_name = "",
        [string] $signature_issuer = ""
    ) {
        return @{
            deleted               = $deleted
            rulestate             = [PSCustomObject]@{
                enabled = $rulestate_enabled
                source  = $rulestate_source
            }
            signature_fingerprint = [PSCustomObject]@{
                algorithm = $signature_fingerprint_algorith
                value     = $signature_fingerprint_value
            }
            company_name          = $signature_company_name
            issuer                = $signature_issuer
        }
    }

    # Method to add certificates
    [void] AddCertificates(
        [hashtable] $certificates # Use CreateCertificatesHashtable method
    ) {
        $this.configuration.certificates.Add($certificates)
    }

    # Method to create a applications hashtable
    [hashtable] CreateApplicationsHashtable(
        [Nullable[bool]] $deleted = $null,
        [Nullable[bool]] $rulestate_enabled = $null,
        [string] $rulestate_source = "PSSymantecSEPM",
        [string] $processfile_sha2 = "",
        [string] $processfile_md5 = "",
        [string] $processfile_name = "",
        [string] $processfile_company = "",
        [Nullable[Int64]] $processfile_size = $null,
        [string] $processfile_description = "",
        [string] $processfile_directory = "",
        [string] $action = ""
    ) {
        return @{
            deleted     = $deleted
            rulestate   = [PSCustomObject]@{
                enabled = $rulestate_enabled
                source  = $rulestate_source
            }
            processfile = [PSCustomObject]@{
                sha2        = $processfile_sha2
                md5         = $processfile_md5
                name        = $processfile_name
                company     = $processfile_company
                size        = $processfile_size
                description = $processfile_description
                directory   = $processfile_directory
            }
            action      = $action
        }
    }

    # Method to add applications
    [void] AddApplications(
        [hashtable] $applications # Use CreateApplicationsHashtable method
    ) {
        $this.configuration.applications.Add($applications)
    }

    # Method to create a denylistrules hashtable
    [hashtable] CreateDenylistrulesHashtable(
        [Nullable[bool]] $deleted = $null,
        [Nullable[bool]] $rulestate_enabled = $null,
        [string] $rulestate_source = "PSSymantecSEPM",
        [string] $processfile_sha2 = "",
        [string] $processfile_md5 = "",
        [string] $processfile_name = "",
        [string] $processfile_company = "",
        [Nullable[Int64]] $processfile_size = $null,
        [string] $processfile_description = "",
        [string] $processfile_directory = "",
        [string] $action = ""
    ) {
        return  @{
            deleted     = $deleted
            rulestate   = [PSCustomObject]@{
                enabled = $rulestate_enabled
                source  = $rulestate_source
            }
            processfile = [PSCustomObject]@{
                sha2        = $processfile_sha2
                md5         = $processfile_md5
                name        = $processfile_name
                company     = $processfile_company
                size        = $processfile_size
                description = $processfile_description
                directory   = $processfile_directory
            }
            action      = $action
        }
    }

    # Method to add denylistrules
    [void] AddDenylistrules(
        [hashtable] $denylistrules # Use CreateDenylistrulesHashtable method
    ) {
        $this.configuration.denylistrules.Add($denylistrules)
    }

    # Method to create a applications_to_monitor hashtable
    [hashtable] CreateApplicationsToMonitorHashtable(
        [Nullable[bool]] $deleted = $null,
        [Nullable[bool]] $rulestate_enabled = $null,
        [string] $rulestate_source = "PSSymantecSEPM",
        [string] $name = ""
    ) {
        return @{
            deleted   = $deleted
            rulestate = [PSCustomObject]@{
                enabled = $rulestate_enabled
                source  = $rulestate_source
            }
            name      = $name
        }
    }

    # Method to add applications_to_monitor
    [void] AddApplicationsToMonitor(
        [hashtable] $applications_to_monitor # Use CreateApplicationsToMonitorHashtable method
    ) {
        $this.configuration.applications_to_monitor.Add($applications_to_monitor)
    }

    # Method to create a knownrisks hashtable
    [hashtable] CreateKnownrisksHashtable(
        [Nullable[bool]] $deleted = $null,
        [Nullable[bool]] $rulestate_enabled = $null,
        [string] $rulestate_source = "PSSymantecSEPM",
        [string] $threat_id = "",
        [string] $threat_name = "",
        [string] $action = ""
    ) {
        return @{
            deleted     = $deleted
            rulestate   = [PSCustomObject]@{
                enabled = $rulestate_enabled
                source  = $rulestate_source
            }
            threat_id   = $threat_id
            threat_name = $threat_name
            action      = $action
        }
    }

    # Method to add knownrisks
    [void] AddKnownrisks(
        [hashtable] $knownrisks # Use CreateKnownrisksHashtable method
    ) {
        $this.configuration.knownrisks.Add($knownrisks)
    }

    # Method to create a tamper_files hashtable
    [hashtable] CreateTamperFilesHashtable(
        [Nullable[bool]] $sonar = $null,
        [Nullable[bool]] $deleted = $null,
        [Nullable[bool]] $rulestate_enabled = $null,
        [string] $rulestate_source = "PSSymantecSEPM",
        [string] $scancategory = "",
        [string] $pathvariable = "",
        [Nullable[bool]] $applicationcontrol = $null,
        [Nullable[bool]] $securityrisk = $null,
        [Nullable[bool]] $recursive = $null
    ) {
        return @{
            sonar              = $sonar
            deleted            = $deleted
            rulestate          = [PSCustomObject]@{
                enabled = $rulestate_enabled
                source  = $rulestate_source
            }
            scancategory       = $scancategory
            pathvariable       = $pathvariable
            applicationcontrol = $applicationcontrol
            securityrisk       = $securityrisk
            recursive          = $recursive
        }
    }

    # Method to add tamper_files
    [void] AddTamperFiles(
        [hashtable] $tamper_files # Use CreateTamperFilesHashtable method
    ) {
        $this.configuration.tamper_files.Add($tamper_files)
    }
}
