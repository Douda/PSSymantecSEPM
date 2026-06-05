# Refactor Candidates

> **PS Sidebar**: In PowerShell modules, duplication often appears as repeated `begin {}` blocks doing auth checks and URI construction across 40+ cmdlets. Feature envy looks like Private functions reaching into `$script:BaseURLv1` when they should receive it as a parameter. The refactor is extracting the shared block into a helper like `Invoke-ABRestMethod` or a module-scoped init function.

---

After TDD cycle, look for:

- **Duplication** → Extract into a Private function or shared module-scoped init
- **Long methods** → Break `process {}` blocks into Private helpers (keep tests on the public cmdlet)
- **Shallow modules** → Combine thin cmdlets or deepen their implementation
- **Feature envy** → Move logic closer to where the data lives
- **Primitive obsession** → Introduce PSCustomObject shapes with PSTypeNames
- **Existing code** the new code reveals as problematic

## PowerShell-specific refactor signals

### Repeated `begin` blocks

```powershell
# Before: duplicated in 40 cmdlets
begin {
    if (-not (Test-SEPMAccessToken)) { Get-SEPMAccessToken | Out-Null }
    if ($SkipCertificateCheck) { $script:SkipCert = $true }
    $URI = $script:BaseURLv1 + "/specific/endpoint"
    $headers = @{ Authorization = "Bearer $($script:accessToken.token)" }
}
```

**Refactor to**: A single Private function that all cmdlets call, or a module init pattern that sets up shared state once.

### Module-scoped variable sprawl

```powershell
# Before: 10 $script: variables set directly from tests
$script:accessToken = $null
$script:SkipCert = $false
$script:BaseURLv1 = '...'
$script:BaseURLv2 = '...'
```

**Consider**: Add a `Reset-ModuleTestState` function. Tests call one function; variable names can change without breaking tests.

### Type name strings everywhere

```powershell
# Before: magic strings
$resp.PSObject.TypeNames.Insert(0, 'SEP.Computer')
$resp.PSObject.TypeNames.Insert(0, 'SEP.Computer')
$resp.PSObject.TypeNames.Insert(0, 'SEP.Computer')
```

**Refactor to**: Constants or a shared `Add-TypeName` helper.

### Hardcoded error messages

```powershell
throw "Computer name not found"
```

**Refactor to**: Named error records or `Write-Error -ErrorId` for catchable, testable error handling.

## General refactoring principles

- **Run tests after every refactor step.** If a refactor breaks a test, stop and understand why before continuing.
- **Never refactor while RED.** Get to GREEN first, then refactor.
- **Extract duplication into Private functions.** The Public cmdlet signatures stay the same; tests don't change.
- **Deepen modules**: move complexity from Public cmdlets into Private/. The cmdlet becomes thinner; the Private/ folder grows richer.
