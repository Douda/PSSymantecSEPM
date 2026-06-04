# SEPM Policies API Reference

**Source:** Symantec Endpoint Protection Manager API Reference v1  
**Base URL:** `https://{SEPM_HOST}:{PORT}/sepm/api`  
**Endpoints:** 42 | **Definitions:** 144

> ⚠️ **Scope:** This spec covers only the **Policies** subset of the SEPM REST API.  
> Endpoints for computers, groups, commands, admins, domains, GUPs, licensing,  
> replication, threats, locations, and file fingerprints are **not** included.

## 📁 Files

| File | Description |
|------|-------------|
| `OpenAPI_SEPM.json` | Full OpenAPI 2.0 (Swagger) spec — source of truth |
| `specs/exceptions.json` | Exception policy (v1 + v2) schemas & endpoints |
| `specs/firewall.json` | Firewall policy schemas & endpoints |
| `specs/hid.json` | High Intensity Detection policy |
| `specs/ips.json` | IPS policy schemas & endpoints |
| `specs/liveupdate.json` | LiveUpdate policy schemas & endpoints |
| `specs/mem.json` | Memory Exploit Mitigation policy |
| `specs/tdad.json` | Threat Defense for AD policy |
| `specs/upgrade.json` | Upgrade policy schemas & endpoints |
| `specs/hostgroups.json` | Host Group policy objects |
| `specs/licensing.json` | Licensing/SAEP endpoint |
| `specs/common.json` | Shared definitions (summary, raw, host types, etc.) |

## 🔗 Endpoint Quick Reference

| Method | Endpoint | Policy Type | Module Cmdlet |
|--------|----------|-------------|---------------|
| `POST` | `/api/v1/policies/exceptions` | policies | Get/Add/Remove-SEPM*Exception |
| `DELETE` | `/api/v1/policies/exceptions/{id}` | policies | Get/Add/Remove-SEPM*Exception |
| `GET` | `/api/v1/policies/exceptions/{id}` | policies | Get/Add/Remove-SEPM*Exception |
| `PATCH` | `/api/v1/policies/exceptions/{id}` | policies | Get/Add/Remove-SEPM*Exception |
| `PUT` | `/api/v1/policies/exceptions/{id}` | policies | Get/Add/Remove-SEPM*Exception |
| `DELETE` | `/api/v1/policies/firewall/{id}` | policies | Get-SEPMFirewallPolicy |
| `GET` | `/api/v1/policies/firewall/{id}` | policies | Get-SEPMFirewallPolicy |
| `POST` | `/api/v1/policies/hid` | policies | - |
| `DELETE` | `/api/v1/policies/hid/{id}` | policies | - |
| `GET` | `/api/v1/policies/hid/{id}` | policies | - |
| `PATCH` | `/api/v1/policies/hid/{id}` | policies | - |
| `PUT` | `/api/v1/policies/hid/{id}` | policies | - |
| `GET` | `/api/v1/policies/ips/{id}` | policies | Get-SEPMIPSPolicy |
| `POST` | `/api/v1/policies/licensing` | policies | - |
| `GET` | `/api/v1/policies/lu/{id}` | policies | - |
| `POST` | `/api/v1/policies/mem` | policies | - |
| `DELETE` | `/api/v1/policies/mem/{id}` | policies | - |
| `GET` | `/api/v1/policies/mem/{id}` | policies | - |
| `PATCH` | `/api/v1/policies/mem/{id}` | policies | - |
| `PUT` | `/api/v1/policies/mem/{id}` | policies | - |
| `POST` | `/api/v1/policies/policy-objects/hostgroups` | hostgroups | - |
| `GET` | `/api/v1/policies/policy-objects/hostgroups/summary` | hostgroups | - |
| `GET` | `/api/v1/policies/policy-objects/hostgroups/{id}` | hostgroups | - |
| `PUT` | `/api/v1/policies/policy-objects/hostgroups/{id}` | hostgroups | - |
| `GET` | `/api/v1/policies/raw/{policy_type}/{id}` | raw | - |
| `GET` | `/api/v1/policies/summary` | summary | - |
| `GET` | `/api/v1/policies/summary/{policy_type}` | summary | - |
| `POST` | `/api/v1/policies/tdad` | policies | Get-TDADPolicy (To_Update/) |
| `DELETE` | `/api/v1/policies/tdad/{id}` | policies | Get-TDADPolicy (To_Update/) |
| `GET` | `/api/v1/policies/tdad/{id}` | policies | Get-TDADPolicy (To_Update/) |
| `PATCH` | `/api/v1/policies/tdad/{id}` | policies | Get-TDADPolicy (To_Update/) |
| `PUT` | `/api/v1/policies/tdad/{id}` | policies | Get-TDADPolicy (To_Update/) |
| `POST` | `/api/v1/policies/upgrade` | policies | - |
| `DELETE` | `/api/v1/policies/upgrade/{id}` | policies | - |
| `GET` | `/api/v1/policies/upgrade/{id}` | policies | - |
| `PATCH` | `/api/v1/policies/upgrade/{id}` | policies | - |
| `PUT` | `/api/v1/policies/upgrade/{id}` | policies | - |
| `POST` | `/api/v2/policies/exceptions` | policies | Get/Add/Remove-SEPM*Exception |
| `DELETE` | `/api/v2/policies/exceptions/{id}` | policies | Get/Add/Remove-SEPM*Exception |
| `GET` | `/api/v2/policies/exceptions/{id}` | policies | Get/Add/Remove-SEPM*Exception |
| `PATCH` | `/api/v2/policies/exceptions/{id}` | policies | Get/Add/Remove-SEPM*Exception |
| `PUT` | `/api/v2/policies/exceptions/{id}` | policies | Get/Add/Remove-SEPM*Exception |

## 📦 Schema Categories

### Exceptions (25)
- `ExceptionThreat`
- `ExceptionsApplicationToMonitor`
- `ExceptionsConfiguration`
- `ExceptionsConfigurationV2`
- `ExceptionsFile`
- `ExceptionsFingerprint`
- `ExceptionsLinuxConfiguration`
- `ExceptionsLockedOptions`
- ... and 17 more

### Firewall (4)
- `FirewallConfiguration`
- `FirewallRuleConfiguration`
- `MacFirewallConfiguration`
- `PolicyFirewallConfigurationObject`

### HID (2)
- `HidConfiguration`
- `PolicyHidConfigurationObject`

### IPS (8)
- `CustomGroupRule`
- `CustomIPSSignatureRule`
- `CustomVariableRule`
- `IPSConfiguration`
- `IPSRuleState`
- `IPSSignatureRule`
- `IpsAndHostsRule`
- `PolicyIPSConfigurationObject`

### LiveUpdate (8)
- `Advanced`
- `CenteralLuServer`
- `FtpProxy`
- `HttpProxy`
- `LuConfiguration`
- `LuSchedule`
- `LuServer`
- `PolicyLuConfigurationObject`

### MEM (3)
- `MemConfiguration`
- `MemLockedOptions`
- `PolicyMemConfigurationMemLockedOptions`

### TDAD (3)
- `PolicyTdadConfigurationObject`
- `TdadConfiguration`
- `TdadElement`

### Upgrade (3)
- `PolicyUpgradeConfigurationObject`
- `UpgradeConfiguration`
- `UpgradeSchedule`

### HostGroup (18)
- `DnsHost`
- `DnsName`
- `Host`
- `HostConfiguration`
- `HostGroup`
- `HostGroupSummary`
- `HostNameData`
- `IpData`
- ... and 10 more

### Common (70)
- `AdapterConfiguration`
- `Annotation`
- `ApplicationConfiguration`
- `AsyncContext`
- `BufferedReader`
- `ClassLoader`
- `ConnectionConfiguration`
- `Cookie`
- ... and 62 more

