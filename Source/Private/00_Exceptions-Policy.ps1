
<# 
Class to manage exceptions policy. 
Create a policy exceptions object and add exception types to it with custom methods
Structure follows the API documentation : https://apidocs.securitycloud.symantec.com/#/doc?id=policies
Section : Update Exceptions Policy
#>
class SEPMPolicyExceptionsStructure {
    [hashtable] $configuration
    [hashtable] $lockedoptions
    [Nullable[bool]] $enabled
    [string] $desc
    [string] $name
    SEPMPolicyExceptionsStructure() {
        $this.configuration = @{
            files                      = [System.Collections.ArrayList]::new()
            non_pe_rules               = [System.Collections.ArrayList]::new()
            directories                = [System.Collections.ArrayList]::new()
            webdomains                 = [System.Collections.ArrayList]::new()
            certificates               = [System.Collections.ArrayList]::new()
            applications               = [System.Collections.ArrayList]::new()
            denylistrules              = [System.Collections.ArrayList]::new()
            applications_to_monitor    = [System.Collections.ArrayList]::new()
            mac                        = @{
                files = [System.Collections.ArrayList]::new()
            }
            linux                      = @{
                directories    = [System.Collections.ArrayList]::new()
                extension_list = @{}
            }
            extension_list             = @{}
            knownrisks                 = [System.Collections.ArrayList]::new()
            tamper_files               = [System.Collections.ArrayList]::new()
            dns_and_host_applications  = [System.Collections.ArrayList]::new()
            dns_and_host_denylistrules = [System.Collections.ArrayList]::new()
        }
        $this.lockedoptions = @{}
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
        $HashTable = @{}

        if ($null -ne $sonar) { $HashTable['sonar'] = $sonar }
        if ($null -ne $deleted) { $HashTable['deleted'] = $deleted }
        if (![string]::IsNullOrEmpty($scancategory)) { $HashTable['scancategory'] = $scancategory }
        if (![string]::IsNullOrEmpty($pathvariable)) { $HashTable['pathvariable'] = $pathvariable }
        if (![string]::IsNullOrEmpty($path)) { $HashTable['path'] = $path }
        if ($null -ne $applicationcontrol) { $HashTable['applicationcontrol'] = $applicationcontrol }
        if ($null -ne $securityrisk) { $HashTable['securityrisk'] = $securityrisk }
        if ($null -ne $recursive) { $HashTable['recursive'] = $recursive }

        $rulestate = @{}

        if ($null -ne $rulestate_enabled) {
            $rulestate['enabled'] = $rulestate_enabled
        }

        if (![string]::IsNullOrEmpty($rulestate_source)) {
            $rulestate['source'] = $rulestate_source
        }

        if ($rulestate.Count -gt 0) {
            $HashTable['rulestate'] = [PSCustomObject]$rulestate
        }

        return $HashTable
    }

    # Method to add files exceptions
    [void] AddConfigurationFilesExceptions(
        [hashtable] $file # Use CreateFilesHashTable method
    ) {
        $this.configuration.files.Add($file)
    }

    # Method to create a non-PE file exception hashtable
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
        $HashTable = @{}

        if ($null -ne $deleted) { $HashTable['deleted'] = $deleted }
        if (![string]::IsNullOrEmpty($scancategory)) { $HashTable['scancategory'] = $scancategory }
        if (![string]::IsNullOrEmpty($scantype)) { $HashTable['scantype'] = $scantype }
        if ($null -ne $recursive) { $HashTable['recursive'] = $recursive }

        if (![string]::IsNullOrEmpty($pathvariable)) {
            $HashTable['pathvariable'] = $pathvariable
        } else {
            throw "The 'pathvariable' parameter is mandatory and cannot be $null or empty."
        }

        if (![string]::IsNullOrEmpty($directory)) {
            $HashTable['directory'] = $directory
        } else {
            throw "The 'directory' parameter is mandatory and cannot be $null or empty."
        }

        $rulestate = @{}

        if ($null -ne $rulestate_enabled) {
            $rulestate['enabled'] = $rulestate_enabled
        }

        if (![string]::IsNullOrEmpty($rulestate_source)) {
            $rulestate['source'] = $rulestate_source
        }

        if ($rulestate.Count -gt 0) {
            $HashTable['rulestate'] = [PSCustomObject]$rulestate
        }

        return $HashTable
    }

    # Method to add directories
    [void] AddConfigurationDirectoriesExceptions(
        [hashtable] $directory # Use CreateDirectoryHashtable method
    ) {
        $this.configuration.directories.Add($directory)
    }

    # Method to create extensions hashtable
    [hashtable] CreateExtensionListHashtable(
        [Nullable[bool]] $deleted = $null,
        [Nullable[bool]] $rulestate_enabled = $null,
        [string] $rulestate_source = "PSSymantecSEPM",
        [string] $scancategory = "",
        [PSObject[]] $extensions = @()
    ) {

        $HashTable = @{}

        if ($null -ne $deleted) { $HashTable['deleted'] = $deleted }
        if (![string]::IsNullOrEmpty($extensions)) { $HashTable['extensions'] = $extensions }
        if (![string]::IsNullOrEmpty($scancategory)) { $HashTable['scancategory'] = $scancategory }

        if ($extensions.Count -eq 0) {
            throw "The 'extensions' parameter is mandatory and cannot be an empty list."
        } else {
            foreach ($extension in $extensions) {
                if ([string]::IsNullOrEmpty($extension)) {
                    throw "The 'extensions' parameter is mandatory and cannot be an empty list."
                }
            }
        }

        $HashTable['extensions'] = $extensions

        $rulestate = @{}

        if ($null -ne $rulestate_enabled) {
            $rulestate['enabled'] = $rulestate_enabled
        }

        if (![string]::IsNullOrEmpty($rulestate_source)) {
            $rulestate['source'] = $rulestate_source
        }

        if ($rulestate.Count -gt 0) {
            $HashTable['rulestate'] = [PSCustomObject]$rulestate
        }

        return $HashTable
    }

    # Method to add extensions
    [void] AddExtensionsList(
        [hashtable] $extensions # Use CreateExtensionListHashtable method
    ) {
        $this.configuration.extension_list = $extensions
    }
    
    # Method to create a webdomains hashtable
    [hashtable] CreateWebdomainsHashtable(
        [Nullable[bool]] $deleted = $null,
        [Nullable[bool]] $rulestate_enabled = $null,
        [string] $rulestate_source = "PSSymantecSEPM",
        [string] $domain = ""
    ) {
        $HashTable = @{}

        if ($null -ne $deleted) { $HashTable['deleted'] = $deleted }
        if ([string]::IsNullOrEmpty($domain)) {
            throw "The 'domain' parameter is mandatory and cannot be $null or empty."
        } else {
            $HashTable['domain'] = $domain
        }

        $rulestate = @{}

        if ($null -ne $rulestate_enabled) {
            $rulestate['enabled'] = $rulestate_enabled
        }

        if (![string]::IsNullOrEmpty($rulestate_source)) {
            $rulestate['source'] = $rulestate_source
        }

        if ($rulestate.Count -gt 0) {
            $HashTable['rulestate'] = [PSCustomObject]$rulestate
        }

        return $HashTable
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
        $HashTable = @{}

        if ($null -ne $deleted) { $HashTable['deleted'] = $deleted }
        if (![string]::IsNullOrEmpty($signature_company_name)) { $HashTable['signature_company_name'] = $signature_company_name }
        if (![string]::IsNullOrEmpty($signature_issuer)) { $HashTable['signature_issuer'] = $signature_issuer }

        $signature_fingerprint = @{}

        if ([string]::IsNullOrEmpty($signature_fingerprint_algorith)) {
            throw "The 'algorithm' parameter is mandatory and cannot be $null or empty."
        } else {
            $signature_fingerprint['algorithm'] = $signature_fingerprint_algorith
        }

        if ([string]::IsNullOrEmpty($signature_fingerprint_value)) {
            throw "The 'value' parameter is mandatory and cannot be $null or empty."
        } else {
            $signature_fingerprint['value'] = $signature_fingerprint_value
        }

        $HashTable['signature_fingerprint'] = [PSCustomObject]$signature_fingerprint
        
        $rulestate = @{}

        if ($null -ne $rulestate_enabled) {
            $rulestate['enabled'] = $rulestate_enabled
        }

        if (![string]::IsNullOrEmpty($rulestate_source)) {
            $rulestate['source'] = $rulestate_source
        }

        if ($rulestate.Count -gt 0) {
            $HashTable['rulestate'] = [PSCustomObject]$rulestate
        }

        return $HashTable
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

        $HashTable = @{}

        if ($null -ne $deleted) { $HashTable['deleted'] = $deleted }
        if (![string]::IsNullOrEmpty($action)) { $HashTable['action'] = $action }
        
        $rulestate = @{}

        if ($null -ne $rulestate_enabled) {
            $rulestate['enabled'] = $rulestate_enabled
        }

        if (![string]::IsNullOrEmpty($rulestate_source)) {
            $rulestate['source'] = $rulestate_source
        }

        if ($rulestate.Count -gt 0) {
            $HashTable['rulestate'] = [PSCustomObject]$rulestate
        }

        $processfile = @{}

        if (![string]::IsNullOrEmpty($processfile_sha2)) {
            $processfile['sha2'] = $processfile_sha2
        }

        if (![string]::IsNullOrEmpty($processfile_md5)) {
            $processfile['md5'] = $processfile_md5
        }

        if (![string]::IsNullOrEmpty($processfile_name)) {
            $processfile['name'] = $processfile_name
        }

        if (![string]::IsNullOrEmpty($processfile_company)) {
            $processfile['company'] = $processfile_company
        }

        if ($null -ne $processfile_size) {
            $processfile['size'] = $processfile_size
        }

        if (![string]::IsNullOrEmpty($processfile_description)) {
            $processfile['description'] = $processfile_description
        }

        if (![string]::IsNullOrEmpty($processfile_directory)) {
            $processfile['directory'] = $processfile_directory
        }

        $HashTable['processfile'] = [PSCustomObject]$processfile

        return $HashTable
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

        $HashTable = @{}

        if ($null -ne $deleted) { $HashTable['deleted'] = $deleted }
        if (![string]::IsNullOrEmpty($action)) { $HashTable['action'] = $action }

        $rulestate = @{}

        if ($null -ne $rulestate_enabled) {
            $rulestate['enabled'] = $rulestate_enabled
        }

        if (![string]::IsNullOrEmpty($rulestate_source)) {
            $rulestate['source'] = $rulestate_source
        }

        if ($rulestate.Count -gt 0) {
            $HashTable['rulestate'] = [PSCustomObject]$rulestate
        }

        $processfile = @{}

        if (![string]::IsNullOrEmpty($processfile_sha2)) {
            $processfile['sha2'] = $processfile_sha2
        }

        if (![string]::IsNullOrEmpty($processfile_md5)) {
            $processfile['md5'] = $processfile_md5
        }

        if (![string]::IsNullOrEmpty($processfile_name)) {
            $processfile['name'] = $processfile_name
        }

        if (![string]::IsNullOrEmpty($processfile_company)) {
            $processfile['company'] = $processfile_company
        }

        if ($null -ne $processfile_size) {
            $processfile['size'] = $processfile_size
        }

        if (![string]::IsNullOrEmpty($processfile_description)) {
            $processfile['description'] = $processfile_description
        }

        if (![string]::IsNullOrEmpty($processfile_directory)) {
            $processfile['directory'] = $processfile_directory
        }

        $HashTable['processfile'] = [PSCustomObject]$processfile

        return $HashTable
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

        $HashTable = @{}

        if ($null -ne $deleted) { $HashTable['deleted'] = $deleted }
        if (![string]::IsNullOrEmpty($name)) { $HashTable['name'] = $name }

        $rulestate = @{}

        if ($null -ne $rulestate_enabled) {
            $rulestate['enabled'] = $rulestate_enabled
        }

        if (![string]::IsNullOrEmpty($rulestate_source)) {
            $rulestate['source'] = $rulestate_source
        }

        if ($rulestate.Count -gt 0) {
            $HashTable['rulestate'] = [PSCustomObject]$rulestate
        }

        return $HashTable
    }

    # Method to add applications_to_monitor
    [void] AddApplicationsToMonitor(
        [hashtable] $applications_to_monitor # Use CreateApplicationsToMonitorHashtable method
    ) {
        $this.configuration.applications_to_monitor.Add($applications_to_monitor)
    }

    # Method to create a mac_files hashtable
    [hashtable] CreateMacFilesHashtable(
        [Nullable[bool]] $deleted = $null,
        [Nullable[bool]] $rulestate_enabled = $null,
        [string] $rulestate_source = "PSSymantecSEPM",
        [string] $pathvariable = "",
        [string] $path = ""
    ) {

        $HashTable = @{}

        if ($null -ne $deleted) { $HashTable['deleted'] = $deleted }
        if (![string]::IsNullOrEmpty($pathvariable)) { $HashTable['pathvariable'] = $pathvariable }
        if (![string]::IsNullOrEmpty($path)) { $HashTable['path'] = $path }

        $rulestate = @{}

        if ($null -ne $rulestate_enabled) {
            $rulestate['enabled'] = $rulestate_enabled
        }

        if (![string]::IsNullOrEmpty($rulestate_source)) {
            $rulestate['source'] = $rulestate_source
        }

        if ($rulestate.Count -gt 0) {
            $HashTable['rulestate'] = [PSCustomObject]$rulestate
        }

        return $HashTable
    }

    # Method to add mac_files
    [void] AddMacFiles(
        [hashtable] $mac_files # Use CreateMacFilesHashtable method
    ) {
        $this.configuration.mac.files.Add($mac_files)
    }

    # Method to create a linux_directories hashtable
    [hashtable] CreateLinuxDirectoryHashtable(
        [Nullable[bool]] $deleted = $null,
        [Nullable[bool]] $rulestate_enabled = $null,
        [string] $rulestate_source = "PSSymantecSEPM",
        [string] $scancategory = "",
        [string] $pathvariable = "",
        [string] $directory = "",
        [Nullable[bool]] $recursive = $null
    ) {

        $HashTable = @{}

        if ($null -ne $deleted) { $HashTable['deleted'] = $deleted }
        if (![string]::IsNullOrEmpty($scancategory)) { $HashTable['scancategory'] = $scancategory }
        if ($null -ne $recursive) { $HashTable['recursive'] = $recursive }

        if (![string]::IsNullOrEmpty($pathvariable)) {
            $HashTable['pathvariable'] = $pathvariable
        } else {
            throw "The 'pathvariable' parameter is mandatory and cannot be $null or empty."
        }

        if (![string]::IsNullOrEmpty($directory)) {
            $HashTable['directory'] = $directory
        } else {
            throw "The 'directory' parameter is mandatory and cannot be $null or empty."
        }

        $rulestate = @{}

        if ($null -ne $rulestate_enabled) {
            $rulestate['enabled'] = $rulestate_enabled
        }

        if (![string]::IsNullOrEmpty($rulestate_source)) {
            $rulestate['source'] = $rulestate_source
        }

        if ($rulestate.Count -gt 0) {
            $HashTable['rulestate'] = [PSCustomObject]$rulestate
        }

        return $HashTable
    }

    # Method to add linux_directories
    [void] AddLinuxDirectory(
        [hashtable] $linux_directories # Use CreateLinuxDirectoryHashtable method
    ) {
        $this.configuration.linux.directories.Add($linux_directories)
    }

    # Method to create a linux_extension_list hashtable
    [hashtable] CreateLinuxExtensionListHashtable(
        [Nullable[bool]] $deleted = $null,
        [Nullable[bool]] $rulestate_enabled = $null,
        [string] $rulestate_source = "PSSymantecSEPM",
        [string] $scancategory = "",
        [PSObject[]] $extensions = @()
    ) {

        $HashTable = @{}

        if ($null -ne $deleted) { $HashTable['deleted'] = $deleted }
        if (![string]::IsNullOrEmpty($extensions)) { $HashTable['extensions'] = $extensions }
        if (![string]::IsNullOrEmpty($scancategory)) { $HashTable['scancategory'] = $scancategory }

        if ($extensions.Count -eq 0) {
            throw "The 'extensions' parameter is mandatory and cannot be an empty list."
        } else {
            foreach ($extension in $extensions) {
                if ([string]::IsNullOrEmpty($extension)) {
                    throw "The 'extensions' parameter is mandatory and cannot be an empty list."
                }
            }
        }

        $HashTable['extensions'] = $extensions

        $rulestate = @{}

        if ($null -ne $rulestate_enabled) {
            $rulestate['enabled'] = $rulestate_enabled
        }

        if (![string]::IsNullOrEmpty($rulestate_source)) {
            $rulestate['source'] = $rulestate_source
        }

        if ($rulestate.Count -gt 0) {
            $HashTable['rulestate'] = [PSCustomObject]$rulestate
        }

        return $HashTable
    }

    # Method to add linux_extension_list
    [void] AddLinuxExtensionList(
        [hashtable] $linux_extension_list # Use CreateLinuxExtensionListHashtable method
    ) {
        $this.configuration.linux.extension_list = $linux_extension_list
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

        $HashTable = @{}

        if ($null -ne $deleted) { $HashTable['deleted'] = $deleted }
        if (![string]::IsNullOrEmpty($action)) { $HashTable['action'] = $action }

        $rulestate = @{}

        if ($null -ne $rulestate_enabled) {
            $rulestate['enabled'] = $rulestate_enabled
        }

        if (![string]::IsNullOrEmpty($rulestate_source)) {
            $rulestate['source'] = $rulestate_source
        }

        if ($rulestate.Count -gt 0) {
            $HashTable['rulestate'] = [PSCustomObject]$rulestate
        }

        $threat = @{}

        if (![string]::IsNullOrEmpty($threat_id)) {
            $threat['id'] = $threat_id
        } else {
            throw "The 'id' parameter is mandatory and cannot be $null or empty."
        }

        if (![string]::IsNullOrEmpty($threat_name)) {
            $threat['name'] = $threat_name
        } else {
            throw "The 'name' parameter is mandatory and cannot be $null or empty."
        }

        $HashTable['threat'] = [PSCustomObject]$threat

        return $HashTable
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
        [string] $path = "",
        [Nullable[bool]] $applicationcontrol = $null,
        [Nullable[bool]] $securityrisk = $null,
        [Nullable[bool]] $recursive = $null
    ) {

        $HashTable = @{}

        if ($null -ne $sonar) { $HashTable['sonar'] = $sonar }
        if ($null -ne $deleted) { $HashTable['deleted'] = $deleted }
        if (![string]::IsNullOrEmpty($scancategory)) { $HashTable['scancategory'] = $scancategory }
        if (![string]::IsNullOrEmpty($pathvariable)) { $HashTable['pathvariable'] = $pathvariable }
        if (![string]::IsNullOrEmpty($path)) { $HashTable['path'] = $path }
        if ($null -ne $applicationcontrol) { $HashTable['applicationcontrol'] = $applicationcontrol }
        if ($null -ne $securityrisk) { $HashTable['securityrisk'] = $securityrisk }
        if ($null -ne $recursive) { $HashTable['recursive'] = $recursive }

        $rulestate = @{}

        if ($null -ne $rulestate_enabled) {
            $rulestate['enabled'] = $rulestate_enabled
        }

        if (![string]::IsNullOrEmpty($rulestate_source)) {
            $rulestate['source'] = $rulestate_source
        }

        if ($rulestate.Count -gt 0) {
            $HashTable['rulestate'] = [PSCustomObject]$rulestate
        }

        return $HashTable
    }

    # Method to add tamper_files
    [void] AddTamperFiles(
        [hashtable] $tamper_files # Use CreateTamperFilesHashtable method
    ) {
        $this.configuration.tamper_files.Add($tamper_files)
    }

    # Method to create a dns_and_host_applications hashtable
    [hashtable] CreateDnsAndHostApplicationsHashtable(
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

        $HashTable = @{}

        if ($null -ne $deleted) { $HashTable['deleted'] = $deleted }
        if (![string]::IsNullOrEmpty($action)) { $HashTable['action'] = $action }

        $rulestate = @{}

        if ($null -ne $rulestate_enabled) {
            $rulestate['enabled'] = $rulestate_enabled
        }

        if (![string]::IsNullOrEmpty($rulestate_source)) {
            $rulestate['source'] = $rulestate_source
        }

        if ($rulestate.Count -gt 0) {
            $HashTable['rulestate'] = [PSCustomObject]$rulestate
        }

        $processfile = @{}

        if (![string]::IsNullOrEmpty($processfile_sha2)) {
            $processfile['sha2'] = $processfile_sha2
        }

        if (![string]::IsNullOrEmpty($processfile_md5)) {
            $processfile['md5'] = $processfile_md5
        }

        if (![string]::IsNullOrEmpty($processfile_name)) {
            $processfile['name'] = $processfile_name
        }

        if (![string]::IsNullOrEmpty($processfile_company)) {
            $processfile['company'] = $processfile_company
        }

        if ($null -ne $processfile_size) {
            $processfile['size'] = $processfile_size
        }

        if (![string]::IsNullOrEmpty($processfile_description)) {
            $processfile['description'] = $processfile_description
        }

        if (![string]::IsNullOrEmpty($processfile_directory)) {
            $processfile['directory'] = $processfile_directory
        }

        $HashTable['processfile'] = [PSCustomObject]$processfile

        return $HashTable
    }

    # Method to add dns_and_host_applications
    [void] AddDnsAndHostApplications(
        [hashtable] $dns_and_host_applications # Use CreateDnsAndHostApplicationsHashtable method
    ) {
        $this.configuration.dns_and_host_applications.Add($dns_and_host_applications)
    }

    # Method to create a dns_and_host_denyrules hashtable
    [hashtable] CreateDnsAndHostDenyrulesHashtable(
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

        $HashTable = @{}

        if ($null -ne $deleted) { $HashTable['deleted'] = $deleted }
        if (![string]::IsNullOrEmpty($action)) { $HashTable['action'] = $action }

        $rulestate = @{}

        if ($null -ne $rulestate_enabled) {
            $rulestate['enabled'] = $rulestate_enabled
        }

        if (![string]::IsNullOrEmpty($rulestate_source)) {
            $rulestate['source'] = $rulestate_source
        }

        if ($rulestate.Count -gt 0) {
            $HashTable['rulestate'] = [PSCustomObject]$rulestate
        }

        $processfile = @{}

        if (![string]::IsNullOrEmpty($processfile_sha2)) {
            $processfile['sha2'] = $processfile_sha2
        }

        if (![string]::IsNullOrEmpty($processfile_md5)) {
            $processfile['md5'] = $processfile_md5
        }

        if (![string]::IsNullOrEmpty($processfile_name)) {
            $processfile['name'] = $processfile_name
        }

        if (![string]::IsNullOrEmpty($processfile_company)) {
            $processfile['company'] = $processfile_company
        }

        if ($null -ne $processfile_size) {
            $processfile['size'] = $processfile_size
        }

        if (![string]::IsNullOrEmpty($processfile_description)) {
            $processfile['description'] = $processfile_description
        }

        if (![string]::IsNullOrEmpty($processfile_directory)) {
            $processfile['directory'] = $processfile_directory
        }

        $HashTable['processfile'] = [PSCustomObject]$processfile

        return $HashTable
    }
}
