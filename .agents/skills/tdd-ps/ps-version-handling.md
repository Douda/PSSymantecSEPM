# PS Version Handling in Tests

Windows Server ships with PowerShell 5.1. Many users never upgrade. Your module must work on both 5.1 and 7+, and your tests must verify both paths.

## The fundamental differences

| Feature | PS 5.1 | PS 7+ |
|---|---|---|
| `Invoke-RestMethod -SkipCertificateCheck` | ❌ Not available | ✔ Available |
| `[System.Net.ServicePointManager]::ServerCertificateValidationCallback` | ✔ Works | ⚠ Deprecated, still works |
| `Add-Type` C# callbacks | ✔ Required for cert bypass | ⚠ Not needed |
| `ForEach-Object -Parallel` | ❌ Not available | ✔ Available |
| `??` null-coalescing | ❌ Not available | ✔ Available |
| Default encoding | UTF-16 LE | UTF-8 |

## The `Invoke-ABRestMethod` pattern

The canonical approach for version-aware HTTP calls:

```powershell
function Invoke-ABRestMethod {
    param([hashtable]$params)

    # Certificate check (both versions)
    if (-not $script:SkipCert) {
        Test-SEPMCertificate -URI $params.Uri
    }

    switch ($PSVersionTable.PSVersion.Major) {
        { $_ -ge 6 } {
            # PS 7+: use built-in -SkipCertificateCheck
            if ($script:SkipCert -eq $true) {
                $resp = Invoke-RestMethod @params -SkipCertificateCheck
            } else {
                $resp = Invoke-RestMethod @params
            }
        }
        default {
            # PS 5.1: use C# callback
            if ($script:SkipCert -eq $true) {
                Skip-Cert
                $resp = Invoke-RestMethod @params
            } else {
                $resp = Invoke-RestMethod @params
            }
        }
    }
    return $resp
}
```

## The `Skip-Cert` C# callback (PS 5.1)

```powershell
function Skip-Cert {
    if (-not ([System.Management.Automation.PSTypeName]'ServerCertificateValidationCallback').Type) {
        $certCallback = @"
            using System;
            using System.Net;
            using System.Net.Security;
            using System.Security.Cryptography.X509Certificates;
            public class ServerCertificateValidationCallback
            {
                public static void Ignore()
                {
                    if (ServicePointManager.ServerCertificateValidationCallback == null)
                    {
                        ServicePointManager.ServerCertificateValidationCallback +=
                            delegate (Object obj, X509Certificate certificate,
                                      X509Chain chain, SslPolicyErrors errors)
                            { return true; };
                    }
                }
            }
"@
        Add-Type $certCallback
    }
    [ServerCertificateValidationCallback]::Ignore()
}
```

The `Add-Type` compiles C# at runtime. The guard (`if (-not ...Type)`) prevents recompilation on subsequent calls.

## Testing version-dependent paths

### Option 1: Mock `$PSVersionTable.PSVersion`

```powershell
Context 'PS 5.1 path' {
    BeforeAll {
        Mock Skip-Cert -ModuleName MyModule {}
        # Force the switch to take the 'default' branch
        # This is fragile - Pester can't easily mock automatic variables
    }
}
```

⚠️ **Problem**: `$PSVersionTable.PSVersion` is an automatic variable and can't be mocked reliably in all Pester versions.

### Option 2: Mock the version-specific commands (preferred)

Instead of trying to mock the PS version, mock what each branch calls:

```powershell
Context 'Certificate skipping - PS 5.1' {
    BeforeAll {
        $script:SkipCert = $true
        Mock Skip-Cert -ModuleName MyModule {}
        Mock Test-SEPMCertificate -ModuleName MyModule {}
        Mock Invoke-RestMethod -ModuleName MyModule { return 'OK' }
    }

    It 'calls Skip-Cert in PS 5.1' {
        Invoke-ABRestMethod -params @{ Uri = 'https://localhost/api' }
        Should -Invoke Skip-Cert -ModuleName MyModule -Exactly 1 -Scope It
    }
}

Context 'Certificate skipping - PS 7+' {
    BeforeAll {
        $script:SkipCert = $true
        Mock Test-SEPMCertificate -ModuleName MyModule {}
        Mock Invoke-RestMethod -ModuleName MyModule { return 'OK' }
    }

    It 'uses -SkipCertificateCheck in PS 7+' {
        Invoke-ABRestMethod -params @{ Uri = 'https://localhost/api' }
        Should -Invoke Invoke-RestMethod -ModuleName MyModule -Exactly 1 -Scope It
        # Verify -SkipCertificateCheck was passed (Pester 5 limitation: can't easily
        # assert on splatted parameter values; test indirectly via SkipCert not being called)
    }
}
```

### Option 3: Run tests in both environments (ideal)

The most reliable approach: run your test suite twice — once in PS 5.1, once in PS 7+. The `switch` branch is determined by the actual runtime, no mocking needed.

For this project, PS 5.1 testing happens via WinRM into the Windows VM:

```bash
# On host: set credentials
export WINRM_USER=<username> WINRM_PASS=<password>

# Copy module to shared volume
cp -r ./Output/PSSymantecSEPM /home/douda/Windows/PSSymantecSEPM

# Run tests remotely on PS 5.1
python3 Scripts/invoke-winrm.py 'C:\Users\<user>\Desktop\Shared\run-tests.ps1'
```

## Encoding: UTF-8 with BOM for PS 5.1

Windows PowerShell 5.1 requires UTF-8 with BOM (`\xef\xbb\xbf`). Without it, Unicode characters in `.ps1` files get mangled and the parser breaks on special characters.

When writing test files that will run on PS 5.1:

```powershell
# Use this in your editor/build step
$content = Get-Content $sourceFile -Raw
$utf8Bom = [System.Text.UTF8Encoding]::new($true)
[System.IO.File]::WriteAllText($targetFile, $content, $utf8Bom)
```

PS 7+ handles both UTF-8 with and without BOM.

## Path separators

Always use forward slashes in `Join-Path -ChildPath`:

```powershell
# Correct: works on both Windows and Linux
Join-Path -Path $moduleRootPath -ChildPath 'Tests/Config/Common-Init.ps1'

# Wrong: breaks on Linux
Join-Path -Path $moduleRootPath -ChildPath 'Tests\Config\Common-Init.ps1'
```

## What this means for TDD

1. **Design for both versions from the start**: If your cmdlet calls `Invoke-RestMethod` directly, it needs version branching. Wrap it in a helper from day one.
2. **Test the helper separately**: `Invoke-ABRestMethod` gets its own tests covering both PS version paths.
3. **Cmdlet tests mock the helper**: `Get-SEPComputers` tests mock `Invoke-ABRestMethod`, not `Invoke-RestMethod` directly. This isolates version complexity.
4. **CI/run-tests in both environments**: A test passing in PS 7+ doesn't guarantee it passes in PS 5.1.
