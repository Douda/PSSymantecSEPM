<# 
Class to manage exceptions policy. 
Create a policy exceptions object and add exception types to it with NewEntry/AddEntry.
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

    # Create a validated exception entry by delegating to Build-ExceptionEntry
    [hashtable] NewEntry(
        [string] $Type,
        [hashtable] $Properties
    ) {
        return Build-ExceptionEntry -Schema $script:_ExceptionSchema -Type $Type -Properties $Properties
    }

    # Add an exception entry to the configuration at the schema-defined ConfigPath
    [void] AddEntry(
        [string] $Type,
        [hashtable] $Entry
    ) {
        $entryDef = $script:_ExceptionSchema[$Type]
        if ($null -eq $entryDef) {
            $validTypes = ($script:_ExceptionSchema.Keys | Sort-Object) -join ', '
            throw "Unknown exception entry type '$Type'. Valid types: $validTypes"
        }

        $configPath = $entryDef.ConfigPath
        $addMethod  = $entryDef.AddMethod
        $parts      = $configPath -split '\.'

        if ($addMethod -eq 'Add') {
            # Navigate to target ArrayList and append
            $target = $this.configuration
            foreach ($part in $parts) {
                $target = $target[$part]
            }
            $target.Add($Entry)
        } elseif ($addMethod -eq 'Set') {
            # Navigate to parent, then assign to leaf (for singleton properties)
            if ($parts.Count -eq 1) {
                $this.configuration[$parts[0]] = $Entry
            } else {
                $parent = $this.configuration
                for ($i = 0; $i -lt $parts.Count - 1; $i++) {
                    $parent = $parent[$parts[$i]]
                }
                $parent[$parts[-1]] = $Entry
            }
        }
    }
}
