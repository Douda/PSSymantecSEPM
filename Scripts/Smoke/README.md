# Smoke Test Migration Status

## Infrastructure (#172 — 2026-06-12)

`Common.ps1` is the unified, platform-agnostic shared infrastructure.
It contains `T`, `Skip`, and `Write-Summary` helpers — zero side effects.
`Bootstrap.ps1` provides `Initialize-SmokeBootstrap` for module import,
cert bypass, and SEPM auth (branches on `$PSVersionTable.PSVersion.Major`).

Each suite uses three files:
- `run.ps7.ps1` — PS7 entry point (dot-sources Bootstrap + Common + Tests)
- `run.ps51.ps1` — PS5.1 entry point (same pattern, Windows paths, UTF-8 BOM)
- `Tests.ps1` — shared test logic

**Deleted files:**
- `Common-Shared.ps1` (interim file, merged into `Common.ps1`)
- `Common-PS51.ps1` (old PS 5.1-specific init, superseded by `run.ps51.ps1` per suite)
- All `batch.ps7.ps1` / `batch.ps51.ps1` files (replaced by run pattern)

## Converted suites (31)

These suites use the new `run.ps7.ps1` / `run.ps51.ps1` entry points
that handle their own platform bootstrapping, then dot-source `Common.ps1`
and their suite-specific `Tests.ps1`.

| Suite | Status |
|---|---|
| `ConfigBackupRestore/` | Converted (#176) |
| `Confirm-SEPMEventInfo/` | Converted (#174) |
| `Export-SEPMFirewallPolicyToExcel/` | Converted (#176) |
| `FileFingerprintList/` | Converted (#175) |
| `Get-SEPMExceptionPolicy/` | Converted (#174) |
| `Get-SEPMFiles/` | Converted (#175) |
| `Get-SEPMFirewallPolicy/` | Converted (#174) |
| `Get-SEPMGroupSettings/` | Converted (#174) |
| `Get-SEPMInfrastructure/` | Converted (#174) |
| `Get-SEPMIpsPolicy/` | Converted (#174) |
| `Get-SEPMLocationXML/` | Converted (#174) |
| `Get-SEPMPolicySnapshot/` | Converted (#174) |
| `Get-SEPMPolicyXML/` | Converted (#174) |
| `Get-SEPMVersion/` | Converted (#174) |
| `Get-SEPSimpleGets1/` | Converted (#153) |
| `Get-SEPSimpleGets2/` | Converted (#174) |
| `Move-SEPClientGroup/` | Converted (#176) |
| `New-SEPMGroup/` | Converted (#154) |
| `Seed-Assignments/` | Converted (#177) |
| `Seed-ExceptionsPolicies/` | Converted (#177) |
| `Seed-Fingerprints/` | Converted (#177) |
| `Seed-HostGroups/` | Converted (#177) |
| `Seed-MEMPolicies/` | Converted (#177) |
| `Seed-SEPMData/` | Converted (#177) |
| `Seed-TDADPolicies/` | Converted (#177) |
| `Seed-UpgradePolicies/` | Converted (#177) |
| `Seed-Validation/` | Converted (#177) |
| `Send-SEPMCommand/` | Converted (#174) |
| `Start-SEPMReplication/` | Converted (#175) |
| `Update-SEPMExceptionPolicy/` | Converted (#155) — includes `Invoke-BootstrapExtensionList` workaround for SEPM API empty-extension_list rejection |
| `Update-SEPMFileFingerprintList/` | Converted (#176) |

## Unconverted suites (1)

This suite still uses the old `batch.ps7.ps1` / `batch.ps51.ps1` pattern.
It was not in scope for #172 and will be converted in a follow-up PR.

| Suite | Status |
|---|---|
| `Get-SEPMLocations/` | Unconverted |
