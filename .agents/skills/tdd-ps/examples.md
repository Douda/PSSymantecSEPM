# Example: Building `Get-SEPMThreatStats` with TDD

This walks through building a real PSSymantecSEPM cmdlet from scratch using red-green-refactor.

## The cmdlet spec

`Get-SEPMThreatStats` returns threat detection statistics from the SEPM API. One behavior, no parameters beyond `-SkipCertificateCheck`. Outputs a `PSCustomObject` with `lastUpdated` and `infectedClients` properties, decorated with `SEP.ThreatStats` PSTypeName.

## Step 0: Read the domain glossary

From `CONTEXT.md`:
- **Client**: machine running Symantec agent (not "computer" or "endpoint")
- **SEPM**: Symantec Endpoint Protection Manager (the server)
- No special term for "threat stats" — the API calls it `stats/threat`

Use these terms in test names.

## Step 1: Plan

- **Public interface**: `Get-SEPMThreatStats [-SkipCertificateCheck]`
- **System boundary**: `Invoke-ABRestMethod` at `$script:BaseURLv1 + "/stats/threat"`
- **Output type**: `PSCustomObject` decorated with `SEP.ThreatStats`
- **Behaviors to test** (just one for this simple cmdlet):
  1. Returns threat stats object with correct shape and type

## Step 2: Write the tracer bullet test (RED)

Create `Tests/Get-SEPMThreatStats.Tests.ps1`:

```powershell
[CmdletBinding()]
param()

$moduleRootPath = Split-Path -Path $PSScriptRoot -Parent
. (Join-Path -Path $moduleRootPath -ChildPath 'Tests/Config/Common-Init.ps1')

Describe 'Get-SEPMThreatStats' {
    InModuleScope PSSymantecSEPM {
        BeforeAll {
            . (Join-Path -Path $moduleRootPath -ChildPath 'Tests/Config/Common-BeforeAll.ps1')
            . (Join-Path -Path $moduleRootPath -ChildPath 'Tests/Config/Common-TestEnvironmentSetup.ps1')

            Mock Test-SEPMAccessToken -ModuleName $script:moduleName { return $true }

            Mock Invoke-ABRestMethod -ModuleName $script:moduleName {
                return [PSCustomObject]@{
                    Stats = [PSCustomObject]@{
                        lastUpdated     = [long]1693912098821
                        infectedClients = 1
                    }
                }
            }
        }

        AfterAll {
            . (Join-Path -Path $moduleRootPath -ChildPath 'Tests/Config/Common-AfterAll.ps1')
        }

        It 'returns threat stats with correct type and shape' {
            $result = Get-SEPMThreatStats
            $result | Should -Not -BeNullOrEmpty
            $result.PSObject.TypeNames[0] | Should -Be 'SEP.ThreatStats'
            $result.lastUpdated | Should -Be 1693912098821
            $result.infectedClients | Should -Be 1
        }
    }
}
```

Run it:

```powershell
Invoke-Pester ./Tests/Get-SEPMThreatStats.Tests.ps1 -Output Normal
```

**Result**: RED — `Get-SEPMThreatStats` doesn't exist yet.

## Step 3: Minimal implementation (GREEN)

Create `Source/Public/Get-SEPMThreatStats.ps1` with exactly enough code to pass:

```powershell
function Get-SEPMThreatStats {
    <#
    .SYNOPSIS
        Gets threat statistics
    .DESCRIPTION
        Gets threat statistics
    .PARAMETER SkipCertificateCheck
        Skip certificate check
    .EXAMPLE
        PS C:\> Get-SEPMThreatStats

        Stats
        -----
        @{lastUpdated=1693912098821; infectedClients=1}

        Gets threat statistics
    #>

    [CmdletBinding()]
    param (
        [Parameter()]
        [switch]
        $SkipCertificateCheck
    )

    begin {
        $test_token = Test-SEPMAccessToken
        if (-not $test_token) {
            Get-SEPMAccessToken | Out-Null
        }
        if ($SkipCertificateCheck) {
            $script:SkipCert = $true
        }
        $URI = $script:BaseURLv1 + "/stats/threat"
        $headers = @{
            "Authorization" = "Bearer " + $script:accessToken.token
            "Content"       = 'application/json'
        }
    }

    process {
        $params = @{
            Method  = 'GET'
            Uri     = $URI
            headers = $headers
        }

        $resp = Invoke-ABRestMethod -params $params
        $resp.Stats.PSObject.TypeNames.Insert(0, 'SEP.ThreatStats')
        return $resp.Stats
    }
}
```

Rebuild the module and run the test:

```powershell
Build-Module -SourcePath ./Source/PSSymantecSEPM.psd1 -SemVer 0.0.1
Import-Module ./Output/PSSymantecSEPM/PSSymantecSEPM.psm1 -Force
Invoke-Pester ./Tests/Get-SEPMThreatStats.Tests.ps1 -Output Normal
```

**Result**: GREEN. The tracer bullet works.

## Step 4: Add more behaviors (if needed)

For this simple cmdlet, the test already covers the full behavior. But if we were building something more complex, we'd now add tests for:

- `-SkipCertificateCheck` sets `$script:SkipCert`
- Error case: API returns null
- What if `$resp.Stats` is missing?

Example for `-SkipCertificateCheck`:

```powershell
Context 'SkipCertificateCheck' {
    BeforeAll {
        $script:SkipCert = $false
        Mock Invoke-ABRestMethod -ModuleName $script:moduleName {
            return [PSCustomObject]@{
                Stats = [PSCustomObject]@{ lastUpdated = [long]0; infectedClients = 0 }
            }
        }
    }

    It 'enables cert skipping' {
        Get-SEPMThreatStats -SkipCertificateCheck
        $script:SkipCert | Should -Be $true
    }
}
```

## Step 5: Refactor

The `begin` block in `Get-SEPMThreatStats` is identical to the one in `Get-SEPClientStatus`, `Get-SEPMLatestDefinition`, and ~40 other cmdlets. The refactor candidate: extract the repeated auth check and URI construction into a shared helper.

**For now**: note the duplication as a candidate but don't refactor yet — the test suite is green and the duplication is consistent across the codebase. File a refactor issue for later.

Run the full test suite to make sure nothing broke:

```powershell
Invoke-Pester ./Tests -Output Normal
```

## The complete test file

```powershell
[CmdletBinding()]
param()

$moduleRootPath = Split-Path -Path $PSScriptRoot -Parent
. (Join-Path -Path $moduleRootPath -ChildPath 'Tests/Config/Common-Init.ps1')

Describe 'Get-SEPMThreatStats' {
    InModuleScope PSSymantecSEPM {
        BeforeAll {
            . (Join-Path -Path $moduleRootPath -ChildPath 'Tests/Config/Common-BeforeAll.ps1')
            . (Join-Path -Path $moduleRootPath -ChildPath 'Tests/Config/Common-TestEnvironmentSetup.ps1')

            Mock Test-SEPMAccessToken -ModuleName $script:moduleName { return $true }
        }

        AfterAll {
            . (Join-Path -Path $moduleRootPath -ChildPath 'Tests/Config/Common-AfterAll.ps1')
        }

        Context 'API returns valid data' {
            BeforeAll {
                Mock Invoke-ABRestMethod -ModuleName $script:moduleName {
                    return [PSCustomObject]@{
                        Stats = [PSCustomObject]@{
                            lastUpdated     = [long]1693912098821
                            infectedClients = 1
                        }
                    }
                }
            }

            It 'returns threat stats with correct type' {
                $result = Get-SEPMThreatStats
                $result.PSObject.TypeNames[0] | Should -Be 'SEP.ThreatStats'
            }

            It 'returns correct property values' {
                $result = Get-SEPMThreatStats
                $result.lastUpdated | Should -Be 1693912098821
                $result.infectedClients | Should -Be 1
            }
        }

        Context 'SkipCertificateCheck' {
            BeforeAll {
                $script:SkipCert = $false
                Mock Invoke-ABRestMethod -ModuleName $script:moduleName {
                    return [PSCustomObject]@{
                        Stats = [PSCustomObject]@{ lastUpdated = [long]0; infectedClients = 0 }
                    }
                }
            }

            It 'enables cert skipping when parameter is used' {
                Get-SEPMThreatStats -SkipCertificateCheck
                $script:SkipCert | Should -Be $true
            }
        }
    }
}
```

## What this example demonstrates

1. **One behavior at a time** — start with the core behavior (returns stats), add edge cases later
2. **Mock at the right boundary** — `Invoke-ABRestMethod` is mocked; `Test-SEPMAccessToken` is mocked. No deeper mocks needed.
3. **Assert on output shape** — PSTypeName, property values. No `Should -Invoke` needed because the output tells the full story.
4. **Test the cert-skip parameter** — verifies the `$script:SkipCert` side effect, which is externally invisible behavior (the user can't observe it from the output)
5. **Minimal implementation** — the cmdlet has exactly what the tests exercise, nothing more
6. **Domain terms** — test names use "threat stats" matching the API, not invented terms
