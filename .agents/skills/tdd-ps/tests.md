# Good and Bad Pester Tests

## Good Tests

**Integration-style**: Test through the public cmdlet with mocked system boundaries. Assert on output shape, type, and content — not internal call counts.

```powershell
# GOOD: Tests observable behavior
Describe 'Get-SEPClientStatus' {
    InModuleScope PSSymantecSEPM {
        BeforeAll {
            # Mock the HTTP boundary only
            Mock Invoke-ABRestMethod -ModuleName PSSymantecSEPM {
                return [PSCustomObject]@{
                    clientCountStatsList = @(
                        [PSCustomObject]@{ status = 'ONLINE';  clientsCount = 212 },
                        [PSCustomObject]@{ status = 'OFFLINE'; clientsCount = 48  }
                    )
                }
            }
        }

        It 'returns client status list with correct shape' {
            $result = Get-SEPClientStatus
            $result.Count | Should -Be 2
            $result[0].status | Should -Be 'ONLINE'
            $result[0].clientsCount | Should -Be 212
            $result[0].PSObject.TypeNames[0] | Should -Be 'SEP.clientStatusList'
        }
    }
}
```

Characteristics:

- Tests behavior users/callers care about
- Uses public cmdlet only (not Private functions)
- Survives internal refactors — you can rename `Invoke-ABRestMethod` internals, add caching, etc.
- Describes WHAT, not HOW
- Asserts on type name (PSTypeName) to verify the decoration happened
- One logical assertion per `It` block

### Pipeline input

PowerShell users expect pipeline support. Test it:

```powershell
It 'accepts ComputerName from the pipeline' {
    $result = "MyComputer" | Get-SEPComputers
    $result.computername | Should -Be "MyComputer"
}
```

This tests `ValueFromPipeline` or `ValueFromPipelineByPropertyName` binding — behavior the user sees, not an internal detail.

### Parameter sets

If your cmdlet has parameter sets, test each one:

```powershell
Context 'By computer name' {
    It 'returns single computer matching name' { ... }
}

Context 'By group name' {
    It 'returns computers in the specified group' { ... }
}
```

---

## Bad Tests

### Mocking too deep (implementation-coupled)

```powershell
# BAD: Mocks internal Private functions excessively
Describe 'Get-SEPComputers' {
    InModuleScope PSSymantecSEPM {
        BeforeAll {
            Mock Build-SEPMQueryURI { return 'https://fake/uri' }
            Mock Test-SEPMAccessToken { return $true }
            Mock Test-SEPMCertificate { }
            Mock Skip-Cert { }
            Mock Invoke-ABRestMethod { return $dummyResponse }
        }

        It 'calls Build-SEPMQueryURI' {
            Get-SEPComputers
            Should -Invoke Build-SEPMQueryURI -Exactly 1
        }
    }
}
```

Red flags:

- Mocking every Private function in the call chain
- Asserting on internal call counts for functions the user doesn't know about
- Test breaks if you add a caching layer or change which Private function builds the URI

**What to do instead**: Mock only the system boundary (`Invoke-ABRestMethod`) and assert on the _output_, not the internal path that produced it.

### Asserting on call counts unnecessarily

```powershell
# SMELLY: Asserts on call count when output would suffice
It 'calls the API once' {
    $result = Get-SEPClientStatus
    Should -Invoke Invoke-ABRestMethod -Exactly 1 -Scope It
}
```

This is a smell because it tests implementation, not behavior. However, it becomes **acceptable** when the call count IS the externally invisible behavior:

- **Pagination**: You can't tell from a flat 105-computer output whether 1 or 2 API calls were made. `Should -Invoke -Exactly 2` is appropriate.
- **Caching**: Testing that a second call to the cmdlet does NOT hit the API again requires asserting on invocation count.
- **Retry logic**: If the cmdlet should retry on failure, you need to verify the retry happened.

**Rule of thumb**: Prefer asserting on output first. Fall back to `Should -Invoke` only when the externally visible output doesn't reveal the behavior.

### Testing Private functions directly

```powershell
# BAD for stateful functions, OK for pure utilities
Describe 'Build-SEPMQueryURI' {
    It 'builds a query string' {
        $result = Build-SEPMQueryURI -BaseURI 'https://api/v1/computers' -QueryStrings @{ sort = 'NAME' }
        $result | Should -Be 'https://api/v1/computers?sort=NAME'
    }
}
```

This is **fine** because `Build-SEPMQueryURI` is a pure function — input in, output out, no side effects, no module state. Pure utility functions are testable in isolation without coupling to implementation.

**Don't** do this for stateful Private functions that read `$script:` variables or call other functions. Test those only through the public cmdlets that consume them.

### Verifying through external means

```powershell
# BAD: Bypasses the module's interface
It 'saves token to disk' {
    Get-SEPMAccessToken
    $content = Get-Content 'C:\Users\...\accessToken.xml' -Raw
    $content | Should -Match 'FakeTokenFromSEPM'
}
```

```powershell
# GOOD: Verifies through the module's own mechanism
It 'caches token for later retrieval' {
    Get-SEPMAccessToken
    $cached = Import-Clixml -Path $script:accessTokenFilePath
    $cached.token | Should -Be 'FakeTokenFromSEPM'
}
```

Even better: use `TestDrive:` so you're never touching the real filesystem.

---

## `Should -Invoke` vs `Assert-MockCalled`

Pester supports two ways to verify mocked calls:

```powershell
# Newer (Pester 5+): Should -Invoke
Should -Invoke Invoke-ABRestMethod -Exactly 2 -Scope It

# Older (Pester 4 compat): Assert-MockCalled
Assert-MockCalled Invoke-ABRestMethod -Exactly 2 -Scope It
```

Prefer `Should -Invoke` in Pester 5+. Use `-Scope It` to reset counters per test so one test's invocations don't leak into the next.
