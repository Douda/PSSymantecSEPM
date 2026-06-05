# Test File Anatomy

## The standard test file skeleton

Every test file follows this structure:

```powershell
[CmdletBinding()]
param()

# 1. Build & Load the module
$moduleRootPath = Split-Path -Path $PSScriptRoot -Parent
. (Join-Path -Path $moduleRootPath -ChildPath 'Tests/Config/Common-Init.ps1')

Describe '<Cmdlet-Name>' {
    InModuleScope <ModuleName> {
        BeforeAll {
            # 2. Backup user config
            . (Join-Path -Path $moduleRootPath -ChildPath 'Tests/Config/Common-BeforeAll.ps1')

            # 3. Set up test environment (TestDrive:, fake XMLs)
            . (Join-Path -Path $moduleRootPath -ChildPath 'Tests/Config/Common-TestEnvironmentSetup.ps1')

            # 4. Load shared fixtures
            . (Join-Path -Path $moduleRootPath -ChildPath 'Tests/DummyDataGenerator.ps1')

            # 5. Mock system boundaries for this test file
            Mock Test-SEPMAccessToken -ModuleName $script:moduleName { return $true }
            Mock Invoke-ABRestMethod -ModuleName $script:moduleName { ... }
        }

        AfterAll {
            # 6. Restore user config
            . (Join-Path -Path $moduleRootPath -ChildPath 'Tests/Config/Common-AfterAll.ps1')
        }

        Context '<Scenario Name>' {
            BeforeAll {
                # 7. Scenario-specific mock setup
            }

            It '<behavior description>' {
                # 8. Act: call the cmdlet
                $result = <Cmdlet-Name> -Param value

                # 9. Assert: check output
                $result | Should -Not -BeNullOrEmpty
                $result.Property | Should -Be 'expected'
            }
        }
    }
}
```

## The 4 config scripts

### `Common-Init.ps1` — Build and load the module

```powershell
$script:moduleName = 'MyModule'
$moduleRootPath = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent)
$ModuleManifestFilePath = Join-Path -Path $moduleRootPath -ChildPath "Source/MyModule.psd1"
$ModuleFilePath = Join-Path -Path $moduleRootPath -ChildPath "Output/MyModule/MyModule.psm1"

Build-Module -SourcePath $ModuleManifestFilePath -SemVer 0.0.1
Import-Module -Name "$ModuleFilePath" -Force
```

This ensures every test run has a fresh module build. Source changes are always reflected.

### `Common-BeforeAll.ps1` — Backup user state

Backs up the user's real config, credentials, and tokens to temp files before tests overwrite them. Saves original file paths so AfterAll can restore them.

### `Common-TestEnvironmentSetup.ps1` — Isolate the test environment

```powershell
# Redirect file paths to TestDrive:
$script:configurationFilePath = Join-Path 'TestDrive:' 'config.xml'
$script:credentialsFilePath  = Join-Path 'TestDrive:' 'creds.xml'
$script:accessTokenFilePath  = Join-Path 'TestDrive:' 'token.xml'

# Seed fake config/creds/token data on TestDrive:
[PSCustomObject]@{ ServerAddress = 'FakeServer'; port = '1234' } |
    Export-Clixml -Path $script:configurationFilePath -Force

$creds = New-Object PSCredential('FakeUser',
    (ConvertTo-SecureString 'FakePass' -AsPlainText -Force))
$creds | Export-Clixml -Path $script:credentialsFilePath -Force

[PSCustomObject]@{
    token              = 'FakeToken'
    tokenExpiration    = (Get-Date).AddSeconds(3600)
    SkipCertificateCheck = $true
} | Export-Clixml -Path $script:accessTokenFilePath -Force

# Load test config into module-scoped variables
$script:accessToken = Import-Clixml -Path $script:accessTokenFilePath
$script:Credential  = Import-Clixml -Path $script:credentialsFilePath
$script:configuration = Import-Clixml -Path $script:configurationFilePath
$script:BaseURLv1 = "https://$($script:configuration.ServerAddress):$($script:configuration.port)/api/v1"
```

After this, the module thinks it has a real config — but everything is on `TestDrive:`.

### `Common-AfterAll.ps1` — Restore user state

Restores file paths, restores backed-up config/creds/token files, deletes temps.

## DummyDataGenerator pattern

One file (`Tests/DummyDataGenerator.ps1`) contains functions that generate realistic API-shaped objects. All test files dot-source it and call the generators.

```powershell
function New-DummyDataComputer {
    [CmdletBinding()]
    param([string]$ComputerName, [string]$GroupName)

    process {
        $obj = New-Object PSObject
        $obj | Add-Member -Name 'computerName' -Value ($ComputerName ?? "WIN-$((Get-Random -Max 9999))")
        $obj | Add-Member -Name 'ipAddresses'   -Value @('10.0.0.1')
        # ... realistic shape matching the real API response
        $obj.PSTypeNames.Insert(0, 'SEP.Computer')
        return $obj
    }
}
```

Benefits:
- **DRY**: Update the fixture shape in one place, all tests benefit
- **Realistic**: Shapes match the actual API response, catching deserialization issues
- **Readable**: Tests express intent (`New-DummyDataComputer -ComputerName "TargetServer"`) rather than inline blobs of `Add-Member` calls

## Test naming with the domain glossary

Use the project's CONTEXT.md terms in Describe/Context/It names. This makes tests self-documenting for domain experts.

```powershell
# Good: uses domain terms (Client, Policy, Group)
Describe 'Get-SEPComputers' {
    Context 'Filtering by Group' {
        It 'returns Clients in the specified Group' { ... }
        It 'includes Clients from child Groups when -IncludeSubGroups' { ... }
    }
}

# Bad: invents terms
Describe 'Get-SEPComputers' {
    Context 'Filtering by folder' { ... }
    It 'returns machines in subfolders' { ... }
}
```

Avoid: Computer/endpoint/host (use Client), Folder/container (use Group), Profile/configuration (use Policy).

## `InModuleScope` — why it's needed

`InModuleScope <ModuleName> { ... }` runs the test block inside the module's scope. Without it:

- `$script:accessToken` is invisible (it's module-scoped)
- Private functions can't be called or mocked
- `Mock -ModuleName` won't find the function

All tests go inside `InModuleScope`. The only code outside it is the module build/load step at the top of the file.

## Managing module-scoped state in tests

Module-scoped variables persist across `It` blocks unless you reset them:

```powershell
Context 'token from disk' {
    BeforeAll {
        $script:accessToken = $null  # Force re-auth from disk
    }
    It 'reads token from disk' { ... }
}

Context 'token from memory' {
    BeforeAll {
        $script:accessToken = [PSCustomObject]@{ token = 'cached'; tokenExpiration = (Get-Date).AddHours(1) }
    }
    It 'uses cached token' { ... }
}
```

**Consider**: If you find yourself setting `$script:` variables directly in many tests, consider adding a dedicated function the tests can call (`Reset-ModuleState` or `Clear-TokenCache`). This makes the test intent clearer and survives variable renames.

## `BeforeAll` vs `BeforeEach`

- **`BeforeAll`**: Runs once per Context/Describe. Use for mock setup, dummy data generation, config paths. Faster.
- **`BeforeEach`**: Runs before every `It` block. Use when each test needs pristine state. Slower — avoid unless needed.

Prefer `BeforeAll` with explicit state resets in test-specific BeforeAll blocks.
