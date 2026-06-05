# The Mocking Spectrum

PowerShell modules have layers. Mock at the right one.

## The spectrum

```
Shallow (preferred) ←————————————————————————————————————————————→ Deep (acceptable when needed)

Mock Invoke-ABRestMethod     Mock Import-SepmConfiguration     Mock Import-Clixml
(mock HTTP responses)        (mock config parsing)             (mock file I/O)

✔ Tests behavior              ⚠ Tests config layer              ⚠ Tests storage layer
✔ Survives internal refactors ⚠ Breaks if config format changes ⚠ Breaks if storage format changes
```

## Layer 1: Mock the HTTP boundary (preferred)

For API-wrapper modules, `Invoke-ABRestMethod` is the system boundary. Mock it to return the JSON/custom-object shape the API would return.

```powershell
BeforeAll {
    . ./Tests/DummyDataGenerator.ps1  # Shared fixtures

    Mock Invoke-ABRestMethod -ModuleName MyModule {
        return [PSCustomObject]@{
            content   = (1..5 | ForEach-Object { New-DummyDataComputer })
            firstPage = $true
            lastPage  = $true
        }
    }
}

It 'returns 5 computers' {
    $result = Get-Computers
    $result.Count | Should -Be 5
}
```

This test survives if you:
- Change which Private function calls `Invoke-ABRestMethod`
- Add retry logic
- Switch from REST to GraphQL internally
- Reorganize the `begin`/`process`/`end` blocks

It only breaks if the API response shape changes — which should break tests because the behavior changed.

## Layer 2: Mock the config/auth layer (when needed)

When testing functions that bootstrap the module state (configuration loading, token retrieval), you need to mock one layer deeper.

```powershell
BeforeAll {
    Mock Import-SepmConfiguration -ModuleName MyModule {
        return [PSCustomObject]@{
            ServerAddress = 'my-server'
            port          = '8446'
        }
    }
}

It 'sets BaseURL from configuration' {
    Initialize-Configuration
    $script:BaseURLv1 | Should -Be 'https://my-server:8446/api/v1'
}
```

This is necessary when the configuration _is_ the behavior under test. You're not testing that `Import-Clixml` works (Microsoft tests that); you're testing that your module correctly derives `BaseURLv1` from config values.

## Layer 3: Mock file I/O (last resort)

When testing storage-layer functions that read/write files, and when `TestDrive:` is impractical, mock the file I/O directly.

```powershell
BeforeAll {
    Mock Import-Clixml -ModuleName MyModule -ParameterFilter {
        $Path -eq $script:accessTokenFilePath
    } {
        return [PSCustomObject]@{
            token = 'fake-token'
            tokenExpiration = (Get-Date).AddHours(1)
        }
    }
}
```

⚠️ **Consider**: Could you use `TestDrive:` + real files instead? Often clearer:

```powershell
# Alternative: use TestDrive: instead of mocking
$script:accessTokenFilePath = Join-Path 'TestDrive:' 'token.xml'
[PSCustomObject]@{ token = 'fake-token' } | Export-Clixml -Path $script:accessTokenFilePath
```

`TestDrive:` is Pester's temporary filesystem. Files written there vanish after the test. It's a true integration test of the storage layer without mocking callbacks.

## What to mock vs what NOT to mock

### DO mock

| Boundary | Pester command | Why |
|---|---|---|
| HTTP/REST calls | `Mock Invoke-ABRestMethod` | External dependency, slow, needs network |
| Auth validation | `Mock Test-SEPMAccessToken { $true }` | Controls auth state without real tokens |
| Certificate checks | `Mock Test-SEPMCertificate {}` | Self-signed certs in test environments |
| Interactive prompts | `Mock Get-Credential { ... }` | No user present during test run |
| Write-* streams | `Mock Write-Warning {}` | Suppress noise, verify warnings separately |

### Do NOT mock (unless testing the function itself)

| What | Why |
|---|---|
| Your own simple Private functions | Mock the boundary they call, not the function |
| Pure utility functions (URI builders, property testers) | Test them directly — no side effects |
| PSCustomObject or data classes | Just create real instances |

### The Pester Mock mechanics

Pester's `Mock` intercepts *command calls* within a scope. Unlike Jest/TypeScript mocks that replace object methods, Pester replaces the command itself.

```powershell
# Basic mock: replaces all calls to Invoke-ABRestMethod
Mock Invoke-ABRestMethod { return $fakeResponse }

# Scoped mock: only within module scope
Mock Invoke-ABRestMethod -ModuleName MyModule { return $fakeResponse }

# Parameter-filtered mock: only when params match
Mock Invoke-ABRestMethod -ParameterFilter {
    $Method -eq 'POST' -and $Uri -match '/authenticate'
} { return $tokenResponse }

# Verifiable mock: test MUST call this or fail
Mock Invoke-ABRestMethod -Verifiable { return $fakeResponse }
# Later:
Should -InvokeVerifiable
```

### Changing mock behavior per test

Use `$script:callCount` or closures to vary behavior across tests:

```powershell
Context 'With pagination' {
    BeforeAll {
        $script:callCount = 0
        Mock Invoke-ABRestMethod -ModuleName MyModule {
            $script:callCount++
            if ($script:callCount -ge 2) {
                return $lastPageResponse
            } else {
                return $firstPageResponse
            }
        }
    }

    It 'fetches all pages' {
        $result = Get-Computers
        Should -Invoke Invoke-ABRestMethod -Exactly 2 -Scope It
    }
}
```
