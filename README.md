# PSSymantecSEPM

This PowerShell module provides a series of cmdlets to interact with the [Symantec Endpoint Protection Manager API](https://apidocs.securitycloud.symantec.com/#/doc?id=ses_auth)

[![PowerShell Gallery Version](https://img.shields.io/powershellgallery/v/PSSymantecSEPM?style=flat-square)](https://www.powershellgallery.com/packages/PSSymantecSEPM)
[![PowerShell Gallery](https://img.shields.io/powershellgallery/dt/PSSymantecSEPM?style=flat-square)](https://www.powershellgallery.com/packages/PSSymantecSEPM)
![GitHub](https://img.shields.io/github/license/Douda/PSSymantecSEPM?style=flat-square)

## Overview
This small project is an attempt to interact with the Symantec Endpoint Protection Manager (SEPM) API via PowerShell

## Installation

2 ways to install this module :
- Via [Powershell Gallery](https://www.powershellgallery.com/packages/PSSymantecSEPM/) with `Install-Module PSSymantecSEPM`
- Build it from sources See [Building your module](##Building-your-module)

## How to use it
- Setup your SEPM & Authentication information
```PowerShell
Set-SepmConfiguration -ServerAddress MySEPMServer -Port 8446
Set-SEPMAuthentication

Please provide your Username and Password
User: admin
Password: **************
```

Note : Any configuration issue or update, you can
```PowerShell
Reset-SEPMConfiguration # reset the configuration
Clear-SEPMAuthentication # clear the authentication
```

## List of commands
```PowerShell
PS C:\PSSymantecSEPM> Get-Command -Module PSSymantecSEPM | Select-Object -Property Name

Clear-SEPMAuthentication
Get-SEPMAdmins
Get-SEPClientDefVersions
Get-SEPClientStatus
Get-SEPClientVersion
Get-SEPComputers
Get-SEPGUPList
Get-SEPMAccessToken
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
Reset-SEPMConfiguration
Set-SEPMAuthentication
Set-SepmConfiguration
Start-SEPMReplication
```

Every command has a help page, eg. `Get-Help Get-SEPComputers`

## Examples
SEP Clients information
```PowerShell
# Get All SEP Clients information
PS C:\PSSymantecSEPM> $AllSepClients = Get-SEPComputers

# Get SEP clients from specific group (including subgroups)
PS C:\PSSymantecSEPM> $EMEAWorkstations = Get-SEPComputers -GroupName "My Company\EMEA\Workstations"

# SEP Online/Offline Clients
PS C:\PSSymantecSEPM> (Get-SEPClientStatus).clientCountStatsList

status  clientsCount
------  ------------
ONLINE          2022
OFFLINE          930

# SEP Clients version
PS C:\GitHub_Projects\PSSymantecSEPM> (Get-SEPClientVersion).clientVersionList

version        clientsCount formattedVersion
-------        ------------ ----------------
11.0.6000.550             1 11.0.6 (11.0 MR6) build 550
12.1.7004.6500            3 12.1.6 (12.1 RU6 MP5) build 7004
12.1.7454.7000           12 12.1.7 (12.1 RU7) build 7454
14.0.3752.1000           38 14.0.3 (14.0 RU3 MP7) build 1000
14.2.3335.1000            1 14.2.3 (14.2 RU3 MP3) build 1000
14.3.510.0000            12 14.3 (14.3) build 0000
14.3.558.0000            10 14.3 (14.3) build 0000
```

Virus Definitions
```PowerShell
# SEP Virus Definitions
PS C:\PSSymantecSEPM> (Get-SEPClientDefVersions).clientDefStatusList

version             clientsCount
-------             ------------
2023-10-19 rev. 003           11
2023-10-19 rev. 002            4
2023-10-18 rev. 023           31
2021-06-02 rev. 017          158
2021-05-17 rev. 008            1

# SEPM Latest Virus Definitions
PS C:\PSSymantecSEPM> Get-SEPMLatestDefinition

contentName publishedBySymantec publishedBySEPM
----------- ------------------- ---------------
AV_DEFS     10/19/2023 rev. 3   10/19/2023 rev. 3
```

GUPs
```PowerShell
PS C:\PSSymantecSEPM> Get-SEPGUPList | Select-Object Computername, AgentVersion, IpAddress, port

computerName    agentVersion   ipAddress     port
------------    ------------   ---------     ----
GUP01           14.3.558.0000  10.0.10.40   2967
GUP02           12.1.7454.7000 10.0.20.205  2967
GUP03           12.1.7454.7000 10.0.30.248  2967
GUP04           12.1.7454.7000 10.0.40.79   2967
```

Policies summary
```PowerShell
# Get All Policies
PS C:\PSSymantecSEPM> $PoliciesSummary = Get-SEPMPoliciesSummary
# Get specific policy type (here firewall, liveupdate)
PS C:\PSSymantecSEPM> $FirewallPolicies = Get-SEPMPoliciesSummary -PolicyType fw
PS C:\PSSymantecSEPM> $LiveUpdatePolicies = Get-SEPMPoliciesSummary -PolicyType lu
```
Full list of policy types
```PowerShell
PS C:\PSSymantecSEPM> Get-SEPMPoliciesSummary | Select-Object -ExpandProperty policytype | Get-Unique | S
ort

adc
av
exceptions
fw
hi
hid
ips
lu
lucontent
mem
msl
ntr
upgrade
```

Policies details

```PowerShell
# Firewall Policy
PS C:\PSSymantecSEPM> Get-SEPMFirewallPolicy -PolicyName "Servers - Firewall Policy"

sources          : 
configuration    : @{enforced_rules=System.Object[]; baseline_rules=System.Object[]; ignore_parent_rules=; smart_dhcp=False; smart_dns=False; smart_wins=False; token_ring_traffic=False; netbios_protection=False; reverse_dns=False; port_scan=False;        
                    dos=False; antimac_spoofing=False; autoblock=False; autoblock_duration=600; stealth_web=False; antiIP_spoofing=False; hide_os=False; windows_firewall=NO_ACTION; windows_firewall_notification=False; endpoint_notification=; p2p_auth=;    
                    mac=}
enabled          : True
desc             : Standard Servers policy
name             : Servers - Firewall Policy
lastmodifiedtime : 1692253688318

# IPS Policy
PS C:\PSSymantecSEPM> Get-SEPMIpsPolicy -PolicyName "Servers - IPS Policy"

sources          : 
configuration    : 
enabled          : True
desc             : 
name             : Servers - IPS Policy
lastmodifiedtime : 1697728232567

# List of all policy types available via PowerShell commands
PS C:\PSSymantecSEPM> Get-Command -Module PSSymantecSEPM | Where-Object { $_.name -like "*Policy*" } | Select Name

Name
----
Get-SEPMExceptionPolicy
Get-SEPMFirewallPolicy
Get-SEPMIpsPolicy
Get-TDADPolicy
```

Database information
```PowerShell
PS C:\PSSymantecSEPM> Get-SEPMDatabaseInfo

name                 : SEPM_SQL_Server
description          : 
address              : 10.0.10.105
instanceName         : 
port                 : 1433
type                 : Microsoft SQL Server
version              : 12.00.5000
installedBySepm      : False
database             : sem5
dbUser               : sem5
dbPasswords          : 
dbTLSRootCertificate : 
```

Threats statistics
```PowerShell
PS C:\PSSymantecSEPM> Get-SEPMThreatStats

Stats
-----
@{lastUpdated=1697729950380; infectedClients=1}
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