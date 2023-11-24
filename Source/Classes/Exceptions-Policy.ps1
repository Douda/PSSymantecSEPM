
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
        $HashTable = @{}

        # Add key/value pairs to the hashtable only if the value is not $null or empty
        if ($null -ne $sonar) { $HashTable['sonar'] = $sonar }
        if ($null -ne $deleted) { $HashTable['deleted'] = $deleted }
        if (![string]::IsNullOrEmpty($scancategory)) { $HashTable['scancategory'] = $scancategory }
        if (![string]::IsNullOrEmpty($pathvariable)) { $HashTable['pathvariable'] = $pathvariable }
        if (![string]::IsNullOrEmpty($path)) { $HashTable['path'] = $path }
        if ($null -ne $applicationcontrol) { $HashTable['applicationcontrol'] = $applicationcontrol }
        if ($null -ne $securityrisk) { $HashTable['securityrisk'] = $securityrisk }
        if ($null -ne $recursive) { $HashTable['recursive'] = $recursive }

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
        # Create an empty hashtable
        $HashTable = @{}

        # Add key/value pairs to the hashtable only if the value is not $null or empty
        if ($null -ne $deleted) { $HashTable['deleted'] = $deleted }
        if (![string]::IsNullOrEmpty($scancategory)) { $HashTable['scancategory'] = $scancategory }
        if (![string]::IsNullOrEmpty($scantype)) { $HashTable['scantype'] = $scantype }
        if (![string]::IsNullOrEmpty($pathvariable)) { $HashTable['pathvariable'] = $pathvariable }
        if (![string]::IsNullOrEmpty($directory)) { $HashTable['directory'] = $directory }
        if ($null -ne $recursive) { $HashTable['recursive'] = $recursive }

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
            $HashTable['rulestate'] = [PSCustomObject]$rulestate
        }

        return $HashTable
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
        # Create an empty hashtable
        $HashTable = @{}

        # Add key/value pairs to the hashtable only if the value is not $null or empty
        if ($null -ne $deleted) { $HashTable['deleted'] = $deleted }
        if ([string]::IsNullOrEmpty($domain)) {
            throw "The 'domain' parameter is mandatory and cannot be $null or empty."
        } else {
            $HashTable['domain'] = $domain
        }

        # RULESTATE
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
        # Create an empty hashtable
        $HashTable = @{}

        # Add key/value pairs to the hashtable only if the value is not $null or empty
        if ($null -ne $deleted) { $HashTable['deleted'] = $deleted }
        if (![string]::IsNullOrEmpty($signature_company_name)) { $HashTable['signature_company_name'] = $signature_company_name }
        if (![string]::IsNullOrEmpty($signature_issuer)) { $HashTable['signature_issuer'] = $signature_issuer }

        # SIGNATURE FINGERPRINT
        # Create an empty hashtable for 'signature_fingerprint'
        $signature_fingerprint = @{}

        # Add 'algorithm' to 'signature_fingerprint' or throw an error if it's $null or empty
        if ([string]::IsNullOrEmpty($signature_fingerprint_algorith)) {
            throw "The 'algorithm' parameter is mandatory and cannot be $null or empty."
        } else {
            $signature_fingerprint['algorithm'] = $signature_fingerprint_algorith
        }

        # Add 'value' to 'signature_fingerprint' or throw an error if it's $null or empty
        if ([string]::IsNullOrEmpty($signature_fingerprint_value)) {
            throw "The 'value' parameter is mandatory and cannot be $null or empty."
        } else {
            $signature_fingerprint['value'] = $signature_fingerprint_value
        }

        # Add 'signature_fingerprint' to the main hashtable
        $HashTable['signature_fingerprint'] = [PSCustomObject]$signature_fingerprint
        
        # RULESTATE
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
        # return @{
        #     deleted     = $deleted
        #     rulestate   = [PSCustomObject]@{
        #         enabled = $rulestate_enabled
        #         source  = $rulestate_source
        #     }
        #     processfile = [PSCustomObject]@{
        #         sha2        = $processfile_sha2
        #         md5         = $processfile_md5
        #         name        = $processfile_name
        #         company     = $processfile_company
        #         size        = $processfile_size
        #         description = $processfile_description
        #         directory   = $processfile_directory
        #     }
        #     action      = $action
        # }

        # Create an empty hashtable
        $HashTable = @{}

        # Add key/value pairs to the hashtable only if the value is not $null or empty
        if ($null -ne $deleted) { $HashTable['deleted'] = $deleted }
        if (![string]::IsNullOrEmpty($action)) { $HashTable['action'] = $action }
        
        # RULESTATE
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
            $HashTable['rulestate'] = [PSCustomObject]$rulestate
        }

        # PROCESSFILE
        # Create an empty hashtable for 'processfile'
        $processfile = @{}

        # Add 'sha2' to 'processfile' only if it's not $null or empty
        if (![string]::IsNullOrEmpty($processfile_sha2)) {
            $processfile['sha2'] = $processfile_sha2
        }

        # Add 'md5' to 'processfile' only if it's not $null or empty
        if (![string]::IsNullOrEmpty($processfile_md5)) {
            $processfile['md5'] = $processfile_md5
        }

        # Add 'name' to 'processfile' only if it's not $null or empty
        if (![string]::IsNullOrEmpty($processfile_name)) {
            $processfile['name'] = $processfile_name
        }

        # Add 'company' to 'processfile' only if it's not $null or empty
        if (![string]::IsNullOrEmpty($processfile_company)) {
            $processfile['company'] = $processfile_company
        }

        # Add 'size' to 'processfile' only if it's not $null or empty
        if ($null -ne $processfile_size) {
            $processfile['size'] = $processfile_size
        }

        # Add 'description' to 'processfile' only if it's not $null or empty
        if (![string]::IsNullOrEmpty($processfile_description)) {
            $processfile['description'] = $processfile_description
        }

        # Add 'directory' to 'processfile' only if it's not $null or empty
        if (![string]::IsNullOrEmpty($processfile_directory)) {
            $processfile['directory'] = $processfile_directory
        }

        # Add 'processfile' to the main hashtable
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
        # return  @{
        #     deleted     = $deleted
        #     rulestate   = [PSCustomObject]@{
        #         enabled = $rulestate_enabled
        #         source  = $rulestate_source
        #     }
        #     processfile = [PSCustomObject]@{
        #         sha2        = $processfile_sha2
        #         md5         = $processfile_md5
        #         name        = $processfile_name
        #         company     = $processfile_company
        #         size        = $processfile_size
        #         description = $processfile_description
        #         directory   = $processfile_directory
        #     }
        #     action      = $action
        # }

        # Create an empty hashtable
        $HashTable = @{}

        # Add key/value pairs to the hashtable only if the value is not $null or empty
        if ($null -ne $deleted) { $HashTable['deleted'] = $deleted }
        if (![string]::IsNullOrEmpty($action)) { $HashTable['action'] = $action }

        # RULESTATE
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
            $HashTable['rulestate'] = [PSCustomObject]$rulestate
        }

        # PROCESSFILE
        # Create an empty hashtable for 'processfile'
        $processfile = @{}

        # Add 'sha2' to 'processfile' only if it's not $null or empty
        if (![string]::IsNullOrEmpty($processfile_sha2)) {
            $processfile['sha2'] = $processfile_sha2
        }

        # Add 'md5' to 'processfile' only if it's not $null or empty
        if (![string]::IsNullOrEmpty($processfile_md5)) {
            $processfile['md5'] = $processfile_md5
        }

        # Add 'name' to 'processfile' only if it's not $null or empty
        if (![string]::IsNullOrEmpty($processfile_name)) {
            $processfile['name'] = $processfile_name
        }

        # Add 'company' to 'processfile' only if it's not $null or empty
        if (![string]::IsNullOrEmpty($processfile_company)) {
            $processfile['company'] = $processfile_company
        }

        # Add 'size' to 'processfile' only if it's not $null or empty
        if ($null -ne $processfile_size) {
            $processfile['size'] = $processfile_size
        }

        # Add 'description' to 'processfile' only if it's not $null or empty
        if (![string]::IsNullOrEmpty($processfile_description)) {
            $processfile['description'] = $processfile_description
        }

        # Add 'directory' to 'processfile' only if it's not $null or empty
        if (![string]::IsNullOrEmpty($processfile_directory)) {
            $processfile['directory'] = $processfile_directory
        }

        # Add 'processfile' to the main hashtable
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
        # return @{
        #     deleted   = $deleted
        #     rulestate = [PSCustomObject]@{
        #         enabled = $rulestate_enabled
        #         source  = $rulestate_source
        #     }
        #     name      = $name
        # }

        # Create an empty hashtable
        $HashTable = @{}

        # Add key/value pairs to the hashtable only if the value is not $null or empty
        if ($null -ne $deleted) { $HashTable['deleted'] = $deleted }
        if (![string]::IsNullOrEmpty($name)) { $HashTable['name'] = $name }

        # RULESTATE
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

    # Method to create a knownrisks hashtable
    [hashtable] CreateKnownrisksHashtable(
        [Nullable[bool]] $deleted = $null,
        [Nullable[bool]] $rulestate_enabled = $null,
        [string] $rulestate_source = "PSSymantecSEPM",
        [string] $threat_id = "",
        [string] $threat_name = "",
        [string] $action = ""
    ) {
        # return @{
        #     deleted     = $deleted
        #     rulestate   = [PSCustomObject]@{
        #         enabled = $rulestate_enabled
        #         source  = $rulestate_source
        #     }
        #     threat_id   = $threat_id
        #     threat_name = $threat_name
        #     action      = $action
        # }

        # Create an empty hashtable
        $HashTable = @{}

        # Add key/value pairs to the hashtable only if the value is not $null or empty
        if ($null -ne $deleted) { $HashTable['deleted'] = $deleted }
        if (![string]::IsNullOrEmpty($action)) { $HashTable['action'] = $action }

        # RULESTATE
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
            $HashTable['rulestate'] = [PSCustomObject]$rulestate
        }

        # THREAT
        # Create an empty hashtable for 'threat'
        $threat = @{}

        # Add 'id' to 'threat' only if it's not $null or empty or throw an error
        if (![string]::IsNullOrEmpty($threat_id)) {
            $threat['id'] = $threat_id
        } else {
            throw "The 'id' parameter is mandatory and cannot be $null or empty."
        }

        # Add 'name' to 'threat' only if it's not $null or empty or throw an error
        if (![string]::IsNullOrEmpty($threat_name)) {
            $threat['name'] = $threat_name
        } else {
            throw "The 'name' parameter is mandatory and cannot be $null or empty."
        }

        # Add 'threat' to the main hashtable
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
        # return @{
        #     sonar              = $sonar
        #     deleted            = $deleted
        #     rulestate          = [PSCustomObject]@{
        #         enabled = $rulestate_enabled
        #         source  = $rulestate_source
        #     }
        #     scancategory       = $scancategory
        #     pathvariable       = $pathvariable
        #     applicationcontrol = $applicationcontrol
        #     securityrisk       = $securityrisk
        #     recursive          = $recursive
        # }

        # Create an empty hashtable
        $HashTable = @{}

        # Add key/value pairs to the hashtable only if the value is not $null or empty
        if ($null -ne $sonar) { $HashTable['sonar'] = $sonar }
        if ($null -ne $deleted) { $HashTable['deleted'] = $deleted }
        if (![string]::IsNullOrEmpty($scancategory)) { $HashTable['scancategory'] = $scancategory }
        if (![string]::IsNullOrEmpty($pathvariable)) { $HashTable['pathvariable'] = $pathvariable }
        if (![string]::IsNullOrEmpty($path)) { $HashTable['path'] = $path }
        if ($null -ne $applicationcontrol) { $HashTable['applicationcontrol'] = $applicationcontrol }
        if ($null -ne $securityrisk) { $HashTable['securityrisk'] = $securityrisk }
        if ($null -ne $recursive) { $HashTable['recursive'] = $recursive }

        # RULESTATE
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
        # return @{
        #     deleted     = $deleted
        #     rulestate   = [PSCustomObject]@{
        #         enabled = $rulestate_enabled
        #         source  = $rulestate_source
        #     }
        #     processfile = [PSCustomObject]@{
        #         sha2        = $processfile_sha2
        #         md5         = $processfile_md5
        #         name        = $processfile_name
        #         company     = $processfile_company
        #         size        = $processfile_size
        #         description = $processfile_description
        #         directory   = $processfile_directory
        #     }
        #     action      = $action
        # }

        # Create an empty hashtable
        $HashTable = @{}

        # Add key/value pairs to the hashtable only if the value is not $null or empty
        if ($null -ne $deleted) { $HashTable['deleted'] = $deleted }
        if (![string]::IsNullOrEmpty($action)) { $HashTable['action'] = $action }

        # RULESTATE
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
            $HashTable['rulestate'] = [PSCustomObject]$rulestate
        }

        # PROCESSFILE
        # Create an empty hashtable for 'processfile'
        $processfile = @{}

        # Add 'sha2' to 'processfile' only if it's not $null or empty
        if (![string]::IsNullOrEmpty($processfile_sha2)) {
            $processfile['sha2'] = $processfile_sha2
        }

        # Add 'md5' to 'processfile' only if it's not $null or empty
        if (![string]::IsNullOrEmpty($processfile_md5)) {
            $processfile['md5'] = $processfile_md5
        }

        # Add 'name' to 'processfile' only if it's not $null or empty
        if (![string]::IsNullOrEmpty($processfile_name)) {
            $processfile['name'] = $processfile_name
        }

        # Add 'company' to 'processfile' only if it's not $null or empty
        if (![string]::IsNullOrEmpty($processfile_company)) {
            $processfile['company'] = $processfile_company
        }

        # Add 'size' to 'processfile' only if it's not $null or empty
        if ($null -ne $processfile_size) {
            $processfile['size'] = $processfile_size
        }

        # Add 'description' to 'processfile' only if it's not $null or empty
        if (![string]::IsNullOrEmpty($processfile_description)) {
            $processfile['description'] = $processfile_description
        }

        # Add 'directory' to 'processfile' only if it's not $null or empty
        if (![string]::IsNullOrEmpty($processfile_directory)) {
            $processfile['directory'] = $processfile_directory
        }

        # Add 'processfile' to the main hashtable
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
        # return @{
        #     deleted     = $deleted
        #     rulestate   = [PSCustomObject]@{
        #         enabled = $rulestate_enabled
        #         source  = $rulestate_source
        #     }
        #     processfile = [PSCustomObject]@{
        #         sha2        = $processfile_sha2
        #         md5         = $processfile_md5
        #         name        = $processfile_name
        #         company     = $processfile_company
        #         size        = $processfile_size
        #         description = $processfile_description
        #         directory   = $processfile_directory
        #     }
        #     action      = $action
        # }

        # Create an empty hashtable
        $HashTable = @{}

        # Add key/value pairs to the hashtable only if the value is not $null or empty
        if ($null -ne $deleted) { $HashTable['deleted'] = $deleted }
        if (![string]::IsNullOrEmpty($action)) { $HashTable['action'] = $action }

        # RULESTATE
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
            $HashTable['rulestate'] = [PSCustomObject]$rulestate
        }

        # PROCESSFILE
        # Create an empty hashtable for 'processfile'
        $processfile = @{}

        # Add 'sha2' to 'processfile' only if it's not $null or empty
        if (![string]::IsNullOrEmpty($processfile_sha2)) {
            $processfile['sha2'] = $processfile_sha2
        }

        # Add 'md5' to 'processfile' only if it's not $null or empty
        if (![string]::IsNullOrEmpty($processfile_md5)) {
            $processfile['md5'] = $processfile_md5
        }

        # Add 'name' to 'processfile' only if it's not $null or empty
        if (![string]::IsNullOrEmpty($processfile_name)) {
            $processfile['name'] = $processfile_name
        }

        # Add 'company' to 'processfile' only if it's not $null or empty
        if (![string]::IsNullOrEmpty($processfile_company)) {
            $processfile['company'] = $processfile_company
        }

        # Add 'size' to 'processfile' only if it's not $null or empty
        if ($null -ne $processfile_size) {
            $processfile['size'] = $processfile_size
        }

        # Add 'description' to 'processfile' only if it's not $null or empty
        if (![string]::IsNullOrEmpty($processfile_description)) {
            $processfile['description'] = $processfile_description
        }

        # Add 'directory' to 'processfile' only if it's not $null or empty
        if (![string]::IsNullOrEmpty($processfile_directory)) {
            $processfile['directory'] = $processfile_directory
        }

        # Add 'processfile' to the main hashtable
        $HashTable['processfile'] = [PSCustomObject]$processfile

        return $HashTable
    }
}
