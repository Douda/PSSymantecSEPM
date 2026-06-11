# Smoke Test Migration Status

## Infrastructure (Slice 4 complete — 2026-06-11)

`Common.ps1` is the unified, platform-agnostic shared infrastructure.
It contains auth, `T`, `Skip`, and `Write-Summary` helpers.
No platform branching — each `run.ps*.ps1` handles its own module import,
cert bypass, and SEPM connection setup before dot-sourcing `Common.ps1`.

**Deleted files:**
- `Common-Shared.ps1` (interim file, merged into `Common.ps1`)
- `Common-PS51.ps1` (old PS 5.1-specific init, superseded by `run.ps51.ps1` per suite)

## Converted suites (3)

These suites use the new `run.ps7.ps1` / `run.ps51.ps1` entry points
that handle their own platform bootstrapping, then dot-source `Common.ps1`
and their suite-specific `Tests.ps1`.

| Suite | Status |
|---|---|
| `Get-SEPSimpleGets1/` | Converted (#153) |
| `New-SEPMGroup/` | Converted (#154) |
| `Update-SEPMExceptionPolicy/` | Converted (#155) — includes `Invoke-BootstrapExtensionList` workaround for SEPM API empty-extension_list rejection |

## Unconverted suites (29)

These suites still use the old `batch.ps7.ps1` / `batch.ps51.ps1` pattern
that dot-sources the deleted `Common.ps1` / `Common-PS51.ps1`.
They are **intentionally broken** and will be converted in follow-up PRs.

| Suite | Status |
|---|---|
| `ConfigBackupRestore/` | Unconverted |
| `Confirm-SEPMEventInfo/` | Unconverted |
| `Export-SEPMFirewallPolicyToExcel/` | Unconverted |
| `FileFingerprintList/` | Unconverted |
| `Get-SEPMExceptionPolicy/` | Unconverted |
| `Get-SEPMFiles/` | Unconverted |
| `Get-SEPMFirewallPolicy/` | Unconverted |
| `Get-SEPMGroupSettings/` | Unconverted |
| `Get-SEPMInfrastructure/` | Unconverted |
| `Get-SEPMIpsPolicy/` | Unconverted |
| `Get-SEPMLocationXML/` | Unconverted |
| `Get-SEPMLocations/` | Unconverted |
| `Get-SEPMPolicySnapshot/` | Unconverted |
| `Get-SEPMPolicyXML/` | Unconverted |
| `Get-SEPMVersion/` | Unconverted |
| `Get-SEPSimpleGets2/` | Unconverted |
| `Move-SEPClientGroup/` | Unconverted |
| `Seed-Assignments/` | Unconverted |
| `Seed-ExceptionsPolicies/` | Unconverted |
| `Seed-Fingerprints/` | Unconverted |
| `Seed-HostGroups/` | Unconverted |
| `Seed-MEMPolicies/` | Unconverted |
| `Seed-SEPMData/` | Unconverted |
| `Seed-TDADPolicies/` | Unconverted |
| `Seed-UpgradePolicies/` | Unconverted |
| `Seed-Validation/` | Unconverted |
| `Send-SEPMCommand/` | Unconverted |
| `Start-SEPMReplication/` | Unconverted |
| `Update-SEPMFileFingerprintList/` | Unconverted |
