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
