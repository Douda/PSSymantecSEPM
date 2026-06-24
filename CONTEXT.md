# PSSymantecSEPM

A PowerShell module wrapping the Symantec Endpoint Protection Manager (SEPM) REST API for
managing endpoint protection across an organization.

## Language

**Client**:
A machine (workstation or server) running the Symantec Endpoint Protection agent software,
managed by SEPM.
_Avoid_: Computer, endpoint, machine, host

**SEPM (Symantec Endpoint Protection Manager)**:
The central management server that administers Clients, Groups, and Policies.
_Avoid_: SEPM server, manager server

**Group**:
A node in a tree hierarchy used to organize Clients and scope Policy assignments.
Groups form a parent-child tree; a Client belongs to exactly one Group.
_Avoid_: Folder, container, organizational unit, host group

**Host**:
A network-addressable entity (MAC, IPv4, IPv6, DNS host, DNS domain, IP range,
IP subnet) used inside Host Groups and firewall rules to define which network
traffic a rule matches. Not a Client — Hosts are network identifiers, not machines.
_Avoid_: Endpoint, target (when referring to a Host inside a rule)

**Host Group**:
A named, reusable policy object containing a list of Hosts. Host Groups are
referenced by firewall and other policies so a common set of network entities
can be shared across rules. Managed under /policies/policy-objects/hostgroups.
_Avoid_: Network group, IP group, host list

**Inventory**:
A point-in-time snapshot of SEPM state collected by `Export-SEPMInventory` —
Version, Domains, Groups, Locations, Policies, Clients, Host Groups, and
infrastructure metadata — persisted as a timestamped `.clixml` blob with
per-category files alongside it. Not a live view; reflects state at fetch time.
_Avoid_: Dump, export, backup

**Location**:
A network-context-aware profile within a Group. A single Client can have multiple
Locations (e.g., Internal, VPN, External) with different Policies applied depending
on which network criteria the Client currently matches (reachable AD server, VPN
adapter state, DNS availability, etc.).
_Avoid_: Site, zone, network profile

**Policy**:
A named collection of security settings applied to Clients via Groups and Locations.
SEPM defines ~13 policy types (AV, Firewall, IPS, Exceptions, LiveUpdate, etc.).
Each Group-Location pair can have one Policy of each type assigned.
_Avoid_: Profile, configuration, ruleset

**Exceptions Policy**:
A Policy type that defines what files, folders, extensions, and processes the
scanning engines should skip.
_Avoid_: Exclusion policy, whitelist, allowlist

**Exception Rule**:
A single entry within an Exceptions Policy — a specific file path, folder path,
file extension, or tamper-protection bypass that tells the scanning engines to
skip that item.
_Avoid_: Exception, exclusion

**Exception Entry**:
An in-memory hashtable representing an Exception Rule before serialization to the
SEPM API. Produced by `Build-ExceptionEntry` from a schema-driven factory and
stored in `SEPMPolicyExceptionsStructure.configuration`. Not a domain concept —
this is the module's internal wire format.
_Avoid_: Exception rule, policy entry

**Command**:
An asynchronous action dispatched through SEPM to one or more Clients. The SEPM
queues the command and the Client executes it when it checks in. Examples: active
scan, full scan, quarantine, update definitions, fetch file, clear iron cache.
_Avoid_: Task, job, action, operation

**Domain**:
A tenant-like administrative partition within SEPM. Each Domain contains its own
Groups, Clients, Policies, and Exception Rules — fully isolated from other Domains.
_Avoid_: Tenant, partition, site

**Administrator**:
A user account with elevated privileges within one or more Domains. System-level
Administrators can manage multiple Domains; domain-scoped Administrators are
limited to a single Domain.
_Avoid_: Admin, user, operator

**Group Update Provider (GUP)**:
A Client designated to cache and distribute content updates (virus definitions,
engine updates) to other Clients in its Group, reducing bandwidth to SEPM.
_Avoid_: Update server, distribution point, relay

**Content**:
Downloadable payloads distributed by SEPM to Clients — virus definitions, engine
updates, and patches. Clients can retrieve Content directly from SEPM, from Symantec
Security Response, or from a local GUP.
_Avoid_: Definitions, signatures, virus defs, AV defs

**Fingerprint List**:
A named list of file hashes (SHA-256) used to explicitly block or allow files across
the organization. SEPM checks files against these lists before applying standard
Policy. Can serve as either a denylist or an allowlist depending on configuration.
_Avoid_: Blacklist, whitelist, hash list, file list

**Replication**:
The process of synchronizing configuration data (Groups, Policies, Clients) between
multiple SEPM servers across sites, ensuring consistent administration and failover.
_Avoid_: Sync, mirroring, pairing

**Event**:
A security incident detected by a Client or SEPM — virus detection, intrusion
attempt, policy violation, or other threat activity. Events may require
administrator acknowledgment.
_Avoid_: Alert, incident, notification, log entry

**Policy Snapshot**:
A PSObject bundling fetched Policy summaries, full Policy objects, and a
Location ID→name map for zero, one, or more Policy types. Built by
`Get-SEPMPolicySnapshot` and consumed by Export-ToExcel cmdlets. Persisted via
`Export-Clixml` for offline use.
_Avoid_: Dump, export bundle, policy collection
