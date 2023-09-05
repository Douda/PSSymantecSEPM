# PSSymantecSEPM

This PowerShell module provides a series of cmdlets to interact with the [Symantec Endpoint Protection Manager API](https://apidocs.securitycloud.symantec.com/#/doc?id=ses_auth)

[![PowerShell Gallery Version](https://img.shields.io/powershellgallery/v/PSSymantecSEPM?style=flat-square)](https://www.powershellgallery.com/packages/PSSymantecSEPM)
[![PowerShell Gallery](https://img.shields.io/powershellgallery/dt/PSSymantecSEPM?style=flat-square)](https://www.powershellgallery.com/packages/PSSymantecSEPM)
![GitHub](https://img.shields.io/github/license/Douda/PSSymantecSEPM?style=flat-square)

## Installation

2 ways to install this module :
- Via [Powershell Gallery](https://www.powershellgallery.com/packages/PSSymantecSEPM/) with `Install-Module PSSymantecSEPM`
- Build it from sources See [Building your module](##Building-your-module)

## How to use it
- `Set-SepmConfiguration` to provide your SEPM information (URL/IP)
- `Set-SepmAuthentication` to provide your SEPM credentials
- You're ready to use the module !

Note : Any configuration issue, you can
- `Reset-SepmConfiguration` to reset the configuration
- `Clear-SepmAuthentication` to clear the authentication

## List of commands
```PowerShell
PS C:\PSSymantecSEPM> Get-Command -Module PSSymantecSEPM | Select-Object -Property Name

Clear-SepmAuthentication
Get-SEPAdmins
Get-SEPClientDefVersions
Get-SEPClientStatus
Get-SEPClientVersion
Get-SEPComputers
Get-SEPGUPList
Get-SepmAccessToken
Get-SEPMDatabaseInfo
Get-SEPMDomain
Get-SEPMEventInfo
Get-SEPMExceptionPolicy
Get-SEPMFileFingerprintList
Get-SEPMFirewallPolicy
Get-SEPMGroups
Get-SEPMIpsPolicy
Get-SEPMLatestDefinition
Get-SEPMPoliciesSummary
Get-SEPMReplicationStatus
Get-SEPMThreatStats
Get-SEPMVersion
Reset-SepmConfiguration
Set-SepmAuthentication
Set-SepmConfiguration
Start-SEPMReplication
```

Every command has a help page, eg. `Get-Help Get-SEPComputers`

## Examples
SEP Clients
```PowerShell
PS C:\PSSymantecSEPM> $AllSepClients = Get-SEPComputers
PS C:\PSSymantecSEPM> $EMEAWorkstations = Get-SEPComputers -GroupName "My Company\EMEA\Workstations"
```

Policies summary
```PowerShell
PS C:\PSSymantecSEPM> $PoliciesSummary = Get-SEPMPoliciesSummary
PS C:\PSSymantecSEPM> $FirewallPolicies = Get-SEPMPoliciesSummary -PolicyType fw
PS C:\PSSymantecSEPM> $LiveUpdatePolicies = Get-SEPMPoliciesSummary -PolicyType lu
```

Policies details
```PowerShell
PS C:\PSSymantecSEPM> Get-SEPMFirewallPolicy -PolicyName "Servers - Firewall Policy"
sources          : 
configuration    : @{enforced_rules=System.Object[]; baseline_rules=System.Object[]; ignore_parent_rules=; smart_dhcp=False; smart_dns=False; smart_wins=False; token_ring_traffic=False; netbios_protection=False; reverse_dns=False; port_scan=False;        
                    dos=False; antimac_spoofing=False; autoblock=False; autoblock_duration=600; stealth_web=False; antiIP_spoofing=False; hide_os=False; windows_firewall=NO_ACTION; windows_firewall_notification=False; endpoint_notification=; p2p_auth=;    
                    mac=}
enabled          : True
desc             : Standard Servers policy
name             : Servers - Firewall Policy
lastmodifiedtime : 1692253688318
```
```Powershell
Get-SEPMIpsPolicy -PolicyName "Servers - IPS Policy"
```


## Building your module
To build the module, you need to have [ModuleBuilder](https://www.powershellgallery.com/packages/ModuleBuilder/)

1. Install ModuleBuilder `Install-Module -Name ModuleBuilder`

2. Clone the PSSymantecSEPM repository
 ```powershell
 git clone https://github.com/Douda/PSSymantecSEPM
cd PSSymantecSEPM
```

3. run `Install-RequiredModule`

4. run `Build-Module .\Source -SemVer 1.0.0`
   
**Note**: a build version will be required when building the module, eg. 1.0.0
compiled module appears in the `Output` folder

5. import the newly built module `Import-Module .\Output\PSSymantecSEPM\1.0.0\PSSymantecSEPM.ps1m -Force`


## Versioning

ModuleBuilder will automatically apply the next semver version
if you have installed [gitversion](https://gitversion.readthedocs.io/en/latest/).

To manually create a new version run `Build-Module .\Source -SemVer 0.0.2`

## Additional Information

ModuleBuilder - https://github.com/PoshCode/ModuleBuilder