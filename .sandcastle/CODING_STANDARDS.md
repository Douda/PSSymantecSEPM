# Coding Standards

## PowerShell Version Compatibility

- Module must support **PowerShell 5.1** (Windows VM) and **PowerShell 7+** (devcontainer/Linux).
- Branch on `$PSVersionTable.PSVersion.Major` when APIs differ between versions.
- **Banned in shared code** (breaks PS 5.1):
  - Null-coalescing operator `??` — use `if ($null -eq $x) { ... }` instead
  - Ternary operator `? :` — use `if/else` instead
  - `-SkipCertificateCheck` parameter on `Invoke-RestMethod` — does not exist in 5.1

## Encoding

- **Windows PowerShell 5.1 requires UTF-8 with BOM**. Files destined for the shared volume (Windows VM) MUST have a UTF-8 BOM prefix (`\xef\xbb\xbf`).
- PowerShell 7+ handles UTF-8 without BOM fine.
- When writing files meant to run on the Windows VM, always add BOM.

## Path Separators

- All `Join-Path -ChildPath` calls must use **forward slashes** — backslashes break on Linux.
- Use `Join-Path` or `[System.IO.Path]::Combine()` — never hardcode `\`.

## Certificate Handling

- **PS 7+**: Use `Invoke-RestMethod -SkipCertificateCheck`
- **PS 5.1**: Use `[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }` to bypass
- The module's `Skip-Cert.ps1` helper provides the C# callback via `Add-Type`

## Naming

- **Exported cmdlets**: `Verb-Noun` format (e.g., `Get-SEPComputers`, `Set-SepmAuthentication`)
- **Internal functions** (Private/): `Verb-Noun` or descriptive PascalCase
- **Variables**: `camelCase` for locals, `PascalCase` for parameters
- **Script-scope**: `$script:VariableName` for module-level state
- **Constants**: `$UPPER_SNAKE_CASE` (rare in PS, prefer `$script:Name`)

## Comment-Based Help

Required on all exported functions. Minimum sections:

```powershell
<#
.SYNOPSIS
    Brief description.
.DESCRIPTION
    Detailed description.
.PARAMETER Name
    Parameter description.
.EXAMPLE
    Example usage.
#>
```

## Test Structure

- One test file per function under `Tests/`, named `FunctionName.Tests.ps1`
- Pester `Describe` / `Context` / `It` blocks
- Test lifecycle/bootstrap via `Tests/TestHelpers/` module (`Initialize-TestEnvironment`, `Clear-TestEnvironment`, `New-TestSession`)
- JSON fixtures in `Tests/fixtures/` for SEPM API response data
- Run: `Invoke-Pester -Path ./Tests -Output Detailed`
- Run single file: `Invoke-Pester -Path ./Tests/Get-SEPComputers.Tests.ps1 -Output Detailed`

## Module Build

- Source is split into individual `.ps1` files under `Source/Public/` and `Source/Private/`
- ModuleBuilder assembles them into a single `.psm1` in `Output/`
- The `zz_` prefix on `zz_Initialize-SepmConfiguration.ps1` ensures it loads last
- Always rebuild after adding new source files: `Build-ModuleLocal`
- Build config: `Source/build.psd1`

## Architecture

- **Auth flow**: token → script scope → disk cache → credentials → POST /identity/authenticate
- **REST layer**: `Invoke-SepmApi` branches on PS version for cert handling
- **Configuration**: `~/.config/PSSymantecSEPM/config.json` + encrypted `creds.xml`
- **Token cache**: `~/.local/share/PSSymantecSEPM/accessToken.xml` (Export-Clixml)
- **Pagination**: cmdlets loop `pageIndex`/`pageSize` until `lastPage == true`

## Commit Format

```
type(scope): description

Closes #N
```

Types: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`
Scope: short module/area name (e.g., `auth`, `computers`, `policies`, `build`)

## Rules

- Atomic commits only (one logical change per commit)
- No commented-out code in committed code
- No TODO comments in committed code
- Do not touch unrelated code or refactor things that are not broken
- Always run `Build-ModuleLocal` + `Invoke-Pester` before committing

## Anti-Patterns

- Do not hardcode paths — use `Join-Path` with forward slashes
- Do not use `??` or ternary — breaks PS 5.1
- Do not assume `-SkipCertificateCheck` exists — version-guard or use callback
- Do not write files without BOM if they will run on the Windows VM
