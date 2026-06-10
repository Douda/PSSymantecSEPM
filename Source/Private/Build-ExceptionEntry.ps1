# Schema-driven exception entry constructor.
#
# Takes a type name, properties hashtable, and schema, and returns a validated
# Exception Entry hashtable ready for insertion into a SEPMExceptionPolicy.
#
# Pure function — does not read module-scoped state. The caller owns the schema
# and passes it via the -Schema parameter.

$script:_ExceptionSchema = @{
    Files = @{
        ConfigPath = 'files'
        AddMethod  = 'Add'
        Required   = @('path')
        Fields     = @{
            path              = @{ type = 'string' }
            pathvariable      = @{ type = 'string' }
            scancategory      = @{ type = 'string'; enum = @('AllScans', 'AutoProtect', 'ScheduledAndOndemand') }
            sonar             = @{ type = 'bool' }
            securityrisk      = @{ type = 'bool' }
            applicationcontrol = @{ type = 'bool' }
            recursive         = @{ type = 'bool' }
        }
    }
    Directories = @{
        ConfigPath = 'directories'
        AddMethod  = 'Add'
        Required   = @('pathvariable', 'directory')
        Fields     = @{
            pathvariable = @{ type = 'string' }
            directory    = @{ type = 'string' }
            scancategory = @{ type = 'string'; enum = @('AllScans', 'AutoProtect', 'ScheduledAndOndemand') }
            scantype     = @{ type = 'string'; enum = @('All', 'SecurityRisk', 'SONAR', 'ApplicationControl', 'AllScans', 'AutoProtect', 'ScheduledAndOndemand') }
            recursive    = @{ type = 'bool' }
        }
    }
    Extensions = @{
        ConfigPath = 'extension_list'
        AddMethod  = 'Set'
        Required   = @('extensions')
        Fields     = @{
            extensions   = @{ type = 'string[]' }
            scancategory = @{ type = 'string'; enum = @('All', 'SecurityRisk', 'SONAR', 'ApplicationControl', 'AllScans', 'AutoProtect', 'ScheduledAndOndemand') }
        }
    }
    Webdomains = @{
        ConfigPath = 'webdomains'
        AddMethod  = 'Add'
        Required   = @('domain')
        Fields     = @{
            domain = @{ type = 'string' }
        }
    }
    Certificates = @{
        ConfigPath = 'certificates'
        AddMethod  = 'Add'
        Required   = @()
        Fields     = @{
            signature_company_name = @{ type = 'string' }
            signature_issuer       = @{ type = 'string' }
        }
        SubObjects = @{
            signature_fingerprint = @{
                Required = @('algorithm', 'value')
                Fields   = @{
                    algorithm = @{ type = 'string' }
                    value     = @{ type = 'string' }
                }
            }
        }
    }
    Applications = @{
        ConfigPath = 'applications'
        AddMethod  = 'Add'
        Required   = @()
        Fields     = @{
            action = @{ type = 'string' }
        }
        SubObjects = @{
            processfile = @{
                Required = @('sha2')
                Fields   = @{
                    sha2        = @{ type = 'string' }
                    md5         = @{ type = 'string' }
                    name        = @{ type = 'string' }
                    company     = @{ type = 'string' }
                    size        = @{ type = 'int64' }
                    description = @{ type = 'string' }
                    directory   = @{ type = 'string' }
                }
            }
        }
    }
    Denylistrules = @{
        ConfigPath = 'denylistrules'
        AddMethod  = 'Add'
        Required   = @()
        Fields     = @{
            action = @{ type = 'string' }
        }
        SubObjects = @{
            processfile = @{
                Required = @('sha2')
                Fields   = @{
                    sha2        = @{ type = 'string' }
                    md5         = @{ type = 'string' }
                    name        = @{ type = 'string' }
                    company     = @{ type = 'string' }
                    size        = @{ type = 'int64' }
                    description = @{ type = 'string' }
                    directory   = @{ type = 'string' }
                }
            }
        }
    }
    AppsToMonitor = @{
        ConfigPath = 'applications_to_monitor'
        AddMethod  = 'Add'
        Required   = @('name')
        Fields     = @{
            name = @{ type = 'string' }
        }
    }
    MacFiles = @{
        ConfigPath = 'mac.files'
        AddMethod  = 'Add'
        Required   = @('pathvariable', 'path')
        Fields     = @{
            pathvariable = @{ type = 'string' }
            path         = @{ type = 'string' }
        }
    }
    LinuxDirectories = @{
        ConfigPath = 'linux.directories'
        AddMethod  = 'Add'
        Required   = @('pathvariable', 'directory')
        Fields     = @{
            pathvariable = @{ type = 'string' }
            directory    = @{ type = 'string' }
            scancategory = @{ type = 'string'; enum = @('AllScans', 'AutoProtect', 'ScheduledAndOndemand') }
            recursive    = @{ type = 'bool' }
        }
    }
    LinuxExtensions = @{
        ConfigPath = 'linux.extension_list'
        AddMethod  = 'Set'
        Required   = @('extensions')
        Fields     = @{
            extensions   = @{ type = 'string[]' }
            scancategory = @{ type = 'string'; enum = @('All', 'SecurityRisk', 'SONAR', 'ApplicationControl', 'AllScans', 'AutoProtect', 'ScheduledAndOndemand') }
        }
    }
    Knownrisks = @{
        ConfigPath = 'knownrisks'
        AddMethod  = 'Add'
        Required   = @()
        Fields     = @{
            action = @{ type = 'string' }
        }
        SubObjects = @{
            threat = @{
                Required = @('id', 'name')
                Fields   = @{
                    id   = @{ type = 'string' }
                    name = @{ type = 'string' }
                }
            }
        }
    }
    TamperFiles = @{
        ConfigPath = 'tamper_files'
        AddMethod  = 'Add'
        Required   = @('path')
        Fields     = @{
            path              = @{ type = 'string' }
            pathvariable      = @{ type = 'string' }
            scancategory      = @{ type = 'string'; enum = @('AllScans', 'AutoProtect', 'ScheduledAndOndemand') }
            sonar             = @{ type = 'bool' }
            securityrisk      = @{ type = 'bool' }
            applicationcontrol = @{ type = 'bool' }
            recursive         = @{ type = 'bool' }
        }
    }
    DnsAndHostApps = @{
        ConfigPath = 'dns_and_host_applications'
        AddMethod  = 'Add'
        Required   = @()
        Fields     = @{
            action = @{ type = 'string' }
        }
        SubObjects = @{
            processfile = @{
                Required = @('sha2')
                Fields   = @{
                    sha2        = @{ type = 'string' }
                    md5         = @{ type = 'string' }
                    name        = @{ type = 'string' }
                    company     = @{ type = 'string' }
                    size        = @{ type = 'int64' }
                    description = @{ type = 'string' }
                    directory   = @{ type = 'string' }
                }
            }
        }
    }
    DnsAndHostDeny = @{
        ConfigPath = 'dns_and_host_denylistrules'
        AddMethod  = 'Add'
        Required   = @()
        Fields     = @{
            action = @{ type = 'string' }
        }
        SubObjects = @{
            processfile = @{
                Required = @('sha2')
                Fields   = @{
                    sha2        = @{ type = 'string' }
                    md5         = @{ type = 'string' }
                    name        = @{ type = 'string' }
                    company     = @{ type = 'string' }
                    size        = @{ type = 'int64' }
                    description = @{ type = 'string' }
                    directory   = @{ type = 'string' }
                }
            }
        }
    }
    NonPEFiles = @{
        ConfigPath = 'non_pe_rules'
        AddMethod  = 'Add'
        Required   = @()
        Fields     = @{
            action = @{ type = 'string' }
        }
        SubObjects = @{
            file = @{
                Required = @('sha2')
                Fields   = @{
                    sha2        = @{ type = 'string' }
                    md5         = @{ type = 'string' }
                    name        = @{ type = 'string' }
                    company     = @{ type = 'string' }
                    size        = @{ type = 'int64' }
                    description = @{ type = 'string' }
                    directory   = @{ type = 'string' }
                }
            }
            actor = @{
                Required = @('sha2')
                Fields   = @{
                    sha2        = @{ type = 'string' }
                    md5         = @{ type = 'string' }
                    name        = @{ type = 'string' }
                    company     = @{ type = 'string' }
                    size        = @{ type = 'int64' }
                    description = @{ type = 'string' }
                    directory   = @{ type = 'string' }
                }
            }
        }
    }
}

function Copy-SchemaFields {
    param([hashtable]$Source, [hashtable]$Target, [hashtable]$FieldDefs)

    foreach ($fieldName in $FieldDefs.Keys) {
        if ($Source.ContainsKey($fieldName)) {
            $value = $Source[$fieldName]
            if ($null -ne $value) {
                if ($value -is [string]) {
                    if (-not [string]::IsNullOrEmpty($value)) {
                        $Target[$fieldName] = $value
                    }
                } else {
                    $Target[$fieldName] = $value
                }
            }
        }
    }
}

function Assert-RequiredFields {
    param([hashtable]$Target, [array]$Required, [string]$Context)

    $missing = @()
    foreach ($reqField in $Required) {
        if (-not $Target.ContainsKey($reqField)) {
            $missing += $reqField
        }
    }
    if ($missing.Count -gt 0) {
        $missingList = ($missing | ForEach-Object { "'$_'" }) -join ', '
        throw "Missing required field $missingList for $Context."
    }
}

function Build-ExceptionEntry {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [hashtable] $Schema,

        [Parameter(Mandatory = $true)]
        [string] $Type,

        [Parameter(Mandatory = $true)]
        [hashtable] $Properties
    )

    $entryDef = $Schema[$Type]
    if ($null -eq $entryDef) {
        $validTypes = ($Schema.Keys | Sort-Object) -join ', '
        throw "Unknown exception entry type '$Type'. Valid types: $validTypes"
    }

    $result = @{}

    Copy-SchemaFields -Source $Properties -Target $result -FieldDefs $entryDef.Fields

    # Build rulestate
    $defaultRulestate = [PSCustomObject]@{ source = 'PSSymantecSEPM' }
    if ($Properties.ContainsKey('rulestate') -and $null -ne $Properties['rulestate']) {
        $result['rulestate'] = [PSCustomObject]$Properties['rulestate']
    } elseif ($Properties.ContainsKey('rulestate_enabled') -and $null -ne $Properties['rulestate_enabled']) {
        $result['rulestate'] = [PSCustomObject]@{
            source  = 'PSSymantecSEPM'
            enabled = $Properties['rulestate_enabled']
        }
    } else {
        $result['rulestate'] = $defaultRulestate
    }

    # Handle deleted flag
    if ($Properties.ContainsKey('deleted') -and $null -ne $Properties['deleted']) {
        $result['deleted'] = $Properties['deleted']
    }

    # Build sub-objects from nested hashtables
    if ($entryDef.ContainsKey('SubObjects') -and $null -ne $entryDef.SubObjects) {
        foreach ($subObjName in $entryDef.SubObjects.Keys) {
            if ($Properties.ContainsKey($subObjName) -and $null -ne $Properties[$subObjName]) {
                $subDef = $entryDef.SubObjects[$subObjName]
                $subResult = @{}

                Copy-SchemaFields -Source $Properties[$subObjName] -Target $subResult -FieldDefs $subDef.Fields

                Assert-RequiredFields -Target $subResult -Required $subDef.Required `
                    -Context "sub-object '$subObjName' in type '$Type'"

                $result[$subObjName] = [PSCustomObject]$subResult
            }
        }
    }

    # Validate enum field values
    foreach ($fieldName in $entryDef.Fields.Keys) {
        $fieldDef = $entryDef.Fields[$fieldName]
        if ($fieldDef.ContainsKey('enum') -and $result.ContainsKey($fieldName)) {
            $value = $result[$fieldName]
            $allowedValues = $fieldDef['enum']
            if ($value -notin $allowedValues) {
                $validList = ($allowedValues | ForEach-Object { "$_" }) -join ', '
                throw "Invalid value '$value' for field '$fieldName' in type '$Type'. Valid values: $validList"
            }
        }
    }

    Assert-RequiredFields -Target $result -Required $entryDef.Required `
        -Context "type '$Type'"

    return $result
}
