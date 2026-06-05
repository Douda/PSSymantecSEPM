# PSSymantecSEPM.TestHelpers — Test lifecycle and fixture functions
#
# Provides Initialize-TestEnvironment and Clear-TestEnvironment for managing
# the test environment lifecycle (build, import, backup, reset, restore),
# and New-TestSession for creating fake session objects.
# Replaces the legacy Tests/Config/Common-*.ps1 dot-sourced scripts.

#Requires -Modules @{ ModuleName = 'ModuleBuilder'; ModuleVersion = '2.0.0' }

function Initialize-TestEnvironment {
    <#
    .SYNOPSIS
        Prepares the PSSymantecSEPM test environment by building and importing the
        module, backing up user configuration, and resetting module state.

    .DESCRIPTION
        This function performs the full test environment initialization:
        1. Builds the PSSymantecSEPM module from source
        2. Imports the built module
        3. Backs up the user's config, credentials, and access token files
        4. Saves the original file paths
        5. Resets configuration to defaults and clears authentication

        Returns a state hashtable that must be passed to Clear-TestEnvironment
        in AfterAll to restore the original files and clean up.

    .EXAMPLE
        BeforeAll {
            Import-Module (Join-Path $PSScriptRoot '../TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
            $script:TestState = Initialize-TestEnvironment
        }

    .OUTPUTS
        System.Collections.Hashtable. Contains backup file paths and original path info.
    #>
    [CmdletBinding()]
    param()

    # Repo root is two levels above this module's directory (Tests/TestHelpers/ → Tests/ → repo root)
    $moduleRootPath = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $manifestPath   = Join-Path -Path $moduleRootPath -ChildPath 'Source/PSSymantecSEPM.psd1'
    $modulePath     = Join-Path -Path $moduleRootPath -ChildPath 'Output/PSSymantecSEPM/PSSymantecSEPM.psm1'

    Write-Verbose "Building PSSymantecSEPM from $manifestPath"
    Build-Module -SourcePath $manifestPath -SemVer 0.0.1

    Write-Verbose "Importing PSSymantecSEPM from $modulePath"
    Import-Module -Name $modulePath -Force -Global

    # Back up user's configuration, credentials, and access token files
    $configBackup = New-TemporaryFile
    Backup-SEPMConfiguration -Path $configBackup

    $credsBackup = New-TemporaryFile
    Backup-SEPMAuthentication -Path $credsBackup -Credential -Force

    $tokenBackup = New-TemporaryFile
    Backup-SEPMAuthentication -Path $tokenBackup -AccessToken -Force

    # Save original file paths before resetting (must read from module scope)
    $originalPaths = InModuleScope PSSymantecSEPM {
        return @{
            ConfigFilePath        = $script:configurationFilePath
            CredentialsFilePath   = $script:credentialsFilePath
            AccessTokenFilePath   = $script:accessTokenFilePath
        }
    }

    Write-Verbose "Resetting configuration and clearing authentication"
    Reset-SEPMConfiguration
    Clear-SEPMAuthentication

    return @{
        ConfigBackup  = $configBackup
        CredsBackup   = $credsBackup
        TokenBackup   = $tokenBackup
        OriginalPaths = $originalPaths
    }
}

function Clear-TestEnvironment {
    <#
    .SYNOPSIS
        Restores the user's original configuration files and cleans up temporary
        backups created by Initialize-TestEnvironment.

    .DESCRIPTION
        This function reverses the effects of Initialize-TestEnvironment:
        1. Restores the original module-scoped file paths
        2. Restores config, credentials, and access token files from backups
        3. Removes the temporary backup files

        Must be called in AfterAll with the state hashtable returned by
        Initialize-TestEnvironment.

    .PARAMETER State
        The state hashtable returned by Initialize-TestEnvironment.

    .EXAMPLE
        AfterAll {
            Clear-TestEnvironment -State $script:TestState
        }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable] $State
    )

    # Restore original file paths in module scope
    InModuleScope PSSymantecSEPM -Parameters @{ State = $State } {
        $script:configurationFilePath = $State.OriginalPaths.ConfigFilePath
        $script:credentialsFilePath   = $State.OriginalPaths.CredentialsFilePath
        $script:accessTokenFilePath   = $State.OriginalPaths.AccessTokenFilePath
    }

    Write-Verbose "Restoring configuration and authentication from backups"
    Restore-SEPMConfiguration -Path $State.ConfigBackup
    Restore-SEPMAuthentication -Path $State.CredsBackup -Credential
    Restore-SEPMAuthentication -Path $State.TokenBackup -AccessToken

    # Clean up temporary backup files
    Write-Verbose "Removing temporary backup files"
    Remove-Item -Path $State.ConfigBackup, $State.CredsBackup, $State.TokenBackup -Force -ErrorAction SilentlyContinue
}

function New-TestSession {
    <#
    .SYNOPSIS
        Creates a fake session object matching the shape returned by
        Initialize-SEPMSession, for use in tests.

    .DESCRIPTION
        Returns a PSCustomObject with Headers, BaseURLv1, BaseURLv2, SkipCert,
        and TokenInfo properties. Use this instead of constructing inline
        [PSCustomObject]@{} hashes in every It block.

    .PARAMETER ServerAddress
        The server hostname or IP. Default: 'FakeServer01'.

    .PARAMETER Port
        The server port. Default: '1234'.

    .PARAMETER Token
        The bearer token value. Default: 'FakeToken'.

    .PARAMETER SkipCert
        If set, SkipCert is $true and certificate validation is bypassed.

    .PARAMETER TokenExpired
        If set, sets the token expiration to 1 hour in the past.

    .EXAMPLE
        # Default session (valid token, no cert skip)
        $session = New-TestSession

    .EXAMPLE
        # Session with expired token and cert skipping
        $session = New-TestSession -SkipCert -TokenExpired

    .EXAMPLE
        # Custom server and token
        $session = New-TestSession -ServerAddress 'MyServer' -Port '8446' -Token 'abc123'
    #>
    [CmdletBinding()]
    param(
        [string] $ServerAddress = 'FakeServer01',
        [string] $Port = '1234',
        [string] $Token = 'FakeToken',
        [switch] $SkipCert,
        [switch] $TokenExpired
    )

    $expiration = if ($TokenExpired) {
        (Get-Date).AddHours(-1)
    } else {
        (Get-Date).AddHours(1)
    }

    return [PSCustomObject]@{
        Headers   = @{
            Authorization = "Bearer $Token"
            Content       = 'application/json'
        }
        BaseURLv1 = "https://${ServerAddress}:${Port}/sepm/api/v1"
        BaseURLv2 = "https://${ServerAddress}:${Port}/sepm/api/v2"
        SkipCert  = $SkipCert.IsPresent
        TokenInfo = [PSCustomObject]@{
            token           = $Token
            tokenExpiration = $expiration
        }
    }
}

function New-DummyComputer {
    <#
    .SYNOPSIS
        Generates a dummy SEP Computer object for testing purposes.

    .DESCRIPTION
        Generates a dummy SEP Computer object matching the shape returned by
        the SEPM API's /computers endpoint. Replaces New-DummyDataSEPComputers
        from the legacy DummyDataGenerator.ps1.

    .PARAMETER ComputerName
        The computer name. If omitted, a random name like WIN-1234 is generated.

    .PARAMETER GroupName
        The group name (e.g. "My Company\\MyGroup"). If omitted, a random name
        like "My Company\\test group 42" is generated.

    .EXAMPLE
        1..3 | New-DummyComputer

        Generates 3 dummy SEP Computer objects with random names and groups.

    .EXAMPLE
        New-DummyComputer -ComputerName "WORKSTATION-01" -GroupName "Default Group"

        Generates a single dummy computer with the specified name and group.
    #>
    [CmdletBinding()]
    param(
        [string] $ComputerName,
        [string] $GroupName
    )

    process {
        $customObject = New-Object PSObject

        if ($ComputerName) {
            $customObject | Add-Member -Type NoteProperty -Name 'computerName' -Value $ComputerName
        } else {
            $customObject | Add-Member -Type NoteProperty -Name 'computerName' -Value ('WIN-' + (Get-Random -Minimum 1 -Maximum 10000))
        }

        $group = New-Object PSObject
        if ($GroupName) {
            $group | Add-Member -Type NoteProperty -Name 'name' -Value $GroupName
        } else {
            $group | Add-Member -Type NoteProperty -Name 'name' -Value ('My Company\test group ' + (Get-Random -Minimum 1 -Maximum 100))
        }
        $group | Add-Member -Type NoteProperty -Name 'id' -Value ([guid]::NewGuid().ToString())
        $group | Add-Member -Type NoteProperty -Name 'fullPathName' -Value $null
        $group | Add-Member -Type NoteProperty -Name 'externalReferenceId' -Value $null
        $group | Add-Member -Type NoteProperty -Name 'source' -Value $null

        $domain = New-Object PSObject
        $domain | Add-Member -Type NoteProperty -Name 'id' -Value ([guid]::NewGuid().ToString())
        $domain | Add-Member -Type NoteProperty -Name 'name' -Value 'Default'
        $group | Add-Member -Type NoteProperty -Name 'domain' -Value $domain
        $customObject | Add-Member -Type NoteProperty -Name 'group' -Value $group

        $ipv4 = ((1..4 | ForEach-Object { Get-Random -Minimum 1 -Maximum 255 }) -join '.')
        $ipv6 = ((1..8 | ForEach-Object { '{0:X4}' -f (Get-Random -Minimum 0x0000 -Maximum 0xFFFF) }) -join ':')
        $customObject | Add-Member -Type NoteProperty -Name 'ipAddresses' -Value @($ipv4, $ipv6)

        $mac = ((1..6 | ForEach-Object { '{0:X2}' -f (Get-Random -Minimum 0 -Maximum 256) }) -join '-')
        $customObject | Add-Member -Type NoteProperty -Name 'macAddresses' -Value @(1..2 | ForEach-Object { $mac })

        $gateways = @(1..4 | ForEach-Object { ((1..4 | ForEach-Object { Get-Random -Minimum 1 -Maximum 255 }) -join '.') })
        $customObject | Add-Member -Type NoteProperty -Name 'gateways' -Value $gateways

        $subnetMasks = @((ForEach-Object { (1..3 | ForEach-Object { Get-Random -Minimum 1 -Maximum 255 }) -join '.' }) + '.0')
        $customObject | Add-Member -Type NoteProperty -Name 'subnetMasks' -Value @($subnetMasks, '64')

        $dnsv4 = ((1..4 | ForEach-Object { Get-Random -Minimum 1 -Maximum 255 }) -join '.')
        $dnsv6 = ((1..8 | ForEach-Object { '{0:X4}' -f (Get-Random -Minimum 0x0000 -Maximum 0xFFFF) }) -join ':')
        $customObject | Add-Member -Type NoteProperty -Name 'dnsServers' -Value @($dnsv4, $dnsv6)

        $Wins = ((1..4 | ForEach-Object { Get-Random -Minimum 1 -Maximum 255 }) -join '.')
        $customObject | Add-Member -Type NoteProperty -Name 'winServers' -Value @(1..2 | ForEach-Object { $Wins })

        $customObject | Add-Member -Type NoteProperty -Name 'description' -Value ('Description of computer id: ' + $group.id)
        $customObject | Add-Member -Type NoteProperty -Name 'lastInventoryDate' -Value (Get-Date)
        $customObject | Add-Member -Type NoteProperty -Name 'lastModifiedDate' -Value (Get-Date)
        $customObject | Add-Member -Type NoteProperty -Name 'createdDate' -Value (Get-Date)
        $customObject | Add-Member -Type NoteProperty -Name 'createdBy' -Value ('User' + (Get-Random -Minimum 1 -Maximum 100))
        $customObject | Add-Member -Type NoteProperty -Name 'lastModifiedBy' -Value ('User' + (Get-Random -Minimum 1 -Maximum 100))
        $customObject | Add-Member -Type NoteProperty -Name 'version' -Value (Get-Random -Minimum 1 -Maximum 10)
        $customObject | Add-Member -Type NoteProperty -Name 'deleted' -Value $false

        return $customObject
    }
}

function New-DummyPolicySummary {
    <#
    .SYNOPSIS
        Generates dummy SEPM policy summary objects for testing purposes.

    .DESCRIPTION
        Generates dummy policy summary objects matching the shape returned by
        the SEPM API's /policies/summary endpoint. Replaces
        New-DummyDataSEPMPoliciesSummary from the legacy DummyDataGenerator.ps1.

    .PARAMETER PolicyName
        The name of the policy. Required when PolicyType is specified.

    .PARAMETER PolicyType
        The type of the policy. Must be one of: hid, exceptions, mem, ntr, av,
        fw, ips, lucontent, lu, hi, adc, msl, upgrade.

    .PARAMETER PoliciesPerPolicyType
        Number of policies to generate per policy type. Default: 1.

    .EXAMPLE
        New-DummyPolicySummary -PolicyName 'My AV Policy' -PolicyType 'av'

        Generates a single policy summary object for the specified policy.

    .EXAMPLE
        New-DummyPolicySummary -PoliciesPerPolicyType 2

        Generates 2 policy summary objects for each of the 13 policy types (26 total).
    #>
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    param(
        [Parameter(ParameterSetName = 'SinglePolicy', Mandatory = $true)]
        [string] $PolicyName,

        [Parameter(ParameterSetName = 'SinglePolicy', Mandatory = $true)]
        [string] $PolicyType,

        [Parameter(ParameterSetName = 'Default')]
        [int] $PoliciesPerPolicyType = 1
    )

    function New-DummyObject {
        param(
            [string] $PolicyName,
            [string] $PolicyType
        )

        $id = -join ((48..57) + (65..70) | Get-Random -Count 64 | ForEach-Object { [char]$_ })
        $lastmodifiedtime = [long]([double]::Parse((Get-Date -UFormat %s)) * 1000)

        return New-Object PSObject -Property @{
            sources               = $null
            enabled               = $true
            desc                  = 'Random description of ' + $PolicyName
            name                  = $PolicyName
            lastmodifiedtime      = $lastmodifiedtime
            id                    = $id
            domainid              = [guid]::NewGuid().ToString()
            policytype            = $PolicyType
            subtype               = $null
            assignedtocloudgroups = $null
            assignedtolocations   = $null
        }
    }

    $policytypes = @('hid', 'exceptions', 'mem', 'ntr', 'av', 'fw', 'ips', 'lucontent', 'lu', 'hi', 'adc', 'msl', 'upgrade')
    $dummyObjects = @()

    if ($PSCmdlet.ParameterSetName -eq 'SinglePolicy') {
        if ($PolicyType -in $policytypes) {
            $dummyObjects += New-DummyObject -PolicyName $PolicyName -PolicyType $PolicyType
        } else {
            Write-Error "Invalid policy type. Please provide one of the following: $($policytypes -join ', ')"
        }
    } else {
        foreach ($policytype in $policytypes) {
            1..$PoliciesPerPolicyType | ForEach-Object {
                $dummyObjects += New-DummyObject -PolicyName ("policy $policytype $_") -PolicyType $policytype
            }
        }
    }

    return $dummyObjects
}
