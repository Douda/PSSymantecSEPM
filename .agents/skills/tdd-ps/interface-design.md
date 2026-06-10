# Interface Design for Testability

Good cmdlet interfaces make testing natural. Bad interfaces force tests to mock deep internals.

## 1. Accept dependencies through module state, don't hardcode

```powershell
# Testable: reads BaseURL from $script: scope (configurable in tests)
function Get-SEPClientStatus {
    begin {
        $URI = $script:BaseURLv1 + "/stats/client/onlinestatus"
    }
}

# Hard to test: hardcoded URL
function Get-SEPClientStatus {
    begin {
        $URI = "https://hardcoded-server:8446/sepm/api/v1/stats/client/onlinestatus"
    }
}
```

**PowerShell pattern**: Shared configuration lives in `$script:` variables set during module initialization. Tests set these to fake values via `Common-TestEnvironmentSetup.ps1` or directly in `BeforeAll`.

**Consider**: If many tests set `$script:BaseURLv1` directly, add a `Set-ModuleTestConfiguration` helper function that wraps all the variable assignments. Tests call the function; variable names can change without changing every test.

## 2. Return results, don't produce side effects as primary output

```powershell
# Testable: outputs to pipeline (test captures $result)
function Get-SEPClientStatus {
    process {
        $resp = Invoke-ABRestMethod -params $params
        $resp.PSObject.TypeNames.Insert(0, 'SEP.clientStatusList')
        return $resp
    }
}

# Hard to test: writes to $script: as primary output
function Get-SEPClientStatus {
    process {
        $resp = Invoke-ABRestMethod -params $params
        $script:LastClientStatus = $resp  # Side effect!
    }
}
```

`Get-` verbs should output objects. Tests capture them with `$result = Get-...`. `Set-` verbs persist state, and tests verify the persistence through a subsequent `Get-` call or by checking `$script:` state.

## 3. Small parameter surface

```powershell
# Good: focused parameters, clear intent
function Get-SEPComputers {
    param(
        [string]$ComputerName,
        [string]$GroupName,
        [switch]$IncludeSubGroups,
        [switch]$SkipCertificateCheck
    )
}

# Bad: too many parameters, hard to test all combinations
function Get-SEPComputers {
    param(
        [string]$ComputerName, [string]$GroupName,
        [string]$IPAddress, [string]$MACAddress,
        [string]$Domain, [string]$OS,
        [switch]$IncludeSubGroups, [switch]$Online,
        [switch]$Offline, [switch]$Infected,
        [int]$PageSize, [int]$PageIndex,
        [switch]$SkipCertificateCheck
    )
}
```

Fewer parameters = fewer test contexts. Use parameter sets to group mutually exclusive options rather than 15 optional switches.

## 4. Pipeline binding

PowerShell users expect pipeline support. Design for it:

```powershell
function Get-SEPComputers {
    param(
        [Parameter(ValueFromPipeline = $true,
                   ValueFromPipelineByPropertyName = $true)]
        [string]$ComputerName
    )
    process {
        # Process each pipeline input
    }
}
```

Test both parameter and pipeline invocation:

```powershell
It 'accepts ComputerName as parameter' {
    $result = Get-SEPComputers -ComputerName "Server01"
    $result.computername | Should -Be "Server01"
}

It 'accepts ComputerName from pipeline' {
    $result = "Server01" | Get-SEPComputers
    $result.computername | Should -Be "Server01"
}
```

## 5. PSTypeName decoration

Decorate output objects with a PSTypeName so users get format-file rendering and tests can verify the right type was produced:

```powershell
# In the cmdlet
$resp.PSObject.TypeNames.Insert(0, 'SEP.Computer')

# In the test
It 'outputs SEP.Computer type' {
    $result = Get-SEPComputers
    $result[0].PSObject.TypeNames[0] | Should -Be 'SEP.Computer'
}
```

This is a behavior the user cares about — it controls how the output renders and whether format files apply. Test it.

## 6. The `begin`/`process`/`end` pattern and testing

Most API-wrapper cmdlets follow this shape:

```powershell
function Get-SEPThing {
    [CmdletBinding()]
    param([switch]$SkipCertificateCheck)

    begin {
        # Auth check, URI construction (once)
        if (-not (Test-SEPMAccessToken)) { Get-SEPMAccessToken | Out-Null }
        if ($SkipCertificateCheck) { $script:SkipCert = $true }
        $URI = $script:BaseURLv1 + "/things"
        $headers = @{ Authorization = "Bearer $($script:accessToken.token)" }
    }

    process {
        # API call, type decoration, output (per pipeline item if applicable)
        $params = @{ Method = 'GET'; Uri = $URI; headers = $headers }
        $resp = Invoke-ABRestMethod -params $params
        $resp.PSObject.TypeNames.Insert(0, 'SEP.Thing')
        return $resp
    }
}
```

This is a testable structure: mock `Invoke-ABRestMethod`, mock `Test-SEPMAccessToken`, set `$script:SkipCert` in tests, and the rest is pure logic.

## 7. `-SkipCertificateCheck` as a standard parameter

Every cmdlet that calls `Invoke-ABRestMethod` needs `-SkipCertificateCheck`. Make it a standard `[switch]` parameter:

```powershell
param(
    [Parameter()]
    [switch]$SkipCertificateCheck
)
```

Tests verify it propagates to the module state:

```powershell
It 'enables cert skipping when -SkipCertificateCheck is used' {
    $script:SkipCert = $false
    Get-SEPThing -SkipCertificateCheck
    $script:SkipCert | Should -Be $true
}
```

## 8. Avoid class constructors for dependencies

PowerShell classes exist but DI through constructors is not idiomatic. Instead:

- **Configuration**: `$script:` variables loaded during module init
- **HTTP client**: `Invoke-ABRestMethod` as a Private function, mockable via Pester
- **Logging**: `Write-Verbose`, `Write-Warning` — mockable via Pester
- **Random/timestamps**: `Get-Date`, `Get-Random` — mockable via Pester

If you find yourself wanting constructor DI, ask: "Can I make this a Private function that Pester can mock?"

## 9. `ShouldProcess` / `-WhatIf` support

For cmdlets that modify state (`Set-`, `Remove-`, `New-`, `Add-`), implement `ShouldProcess`:

```powershell
[CmdletBinding(SupportsShouldProcess = $true)]
param(...)

process {
    if ($PSCmdlet.ShouldProcess("Target description", "Operation")) {
        # Actual modification
    }
}
```

Tests verify the safeguard:

```powershell
It 'does nothing with -WhatIf' {
    $result = Remove-SEPMGroup -Name "TestGroup" -WhatIf
    $result | Should -BeNullOrEmpty
    Should -Invoke Invoke-ABRestMethod -Exactly 0 -Scope It
}
```
