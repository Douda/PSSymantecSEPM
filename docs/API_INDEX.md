# SEPM API Reference

**Source:** Symantec Endpoint Protection Manager API Reference v1  
**Base URL:** `https://{SEPM_HOST}:{PORT}/sepm/api/v1`  
**Endpoints:** 194 | **Definitions:** 265 | **Categories:** 22  

- [Raw source files](source/) — downloaded from Broadcom SEPM API portal
- [Unified spec](OpenAPI_SEPM_full.json) — single merged Swagger 2.0 file
- [Spec shards](specs/) — self-contained files per category

---

## Endpoints

### admin

| Method | Endpoint | Summary |
|--------|----------|---------|
| GET    | `/api/v1/admin/database` | Gets the database infromation of local site. |
| GET    | `/api/v1/admin/password-settings` | Gets the server password settings. |
| PATCH  | `/api/v1/admin/password-settings` | Updates the server password settings. |
| PUT    | `/api/v1/admin/password-settings` | Updates the server password settings. |
| GET    | `/api/v1/admin/servers` | Gets the list of servers present in SEPM. A system administrator account is required for this REST API. |
| PATCH  | `/api/v1/admin/servers/{id}` |  |
| DELETE | `/api/v1/admin/tdadserver` | Delete TDAD server information.  |
| GET    | `/api/v1/admin/tdadserver` | Retrieve TDAD server information.  |
| POST   | `/api/v1/admin/tdadserver` | Update TDAD server information.  |

### admin-users

| Method | Endpoint | Summary |
|--------|----------|---------|
| GET    | `/api/v1/admin-users` | Gets the list of administrators for a particular domain. |
| POST   | `/api/v1/admin-users` | Create a new administrator with the details that are provided. |
| GET    | `/api/v1/admin-users/{id}` | Gets the details of a single administrator. |
| PUT    | `/api/v1/admin-users/{id}` | Updates the details for a specified administrator. |

### cloud

| Method | Endpoint | Summary |
|--------|----------|---------|
| POST   | `/api/v1/cloud/epmp/account/admin` | Create CDM admin account upon successful PIN validation |
| POST   | `/api/v1/cloud/epmp/account/email` | verify cloud account email |
| POST   | `/api/v1/cloud/epmp/asset_sync_reset` | Request to schedule a job to reset HUB service asset sync marker. |
| GET    | `/api/v1/cloud/epmp/asset_sync_reset/{id}` | Gets the status of the HUB asset sync reset job. |
| GET    | `/api/v1/cloud/epmp/cloud_enrollment` | Retrieve the Cloud's domain enrollment status. A system administrator account is required for this REST API. |
| GET    | `/api/v1/cloud/epmp/cloud_test_connections` | Test Cloud Connections. A system administrator account is required for this REST API. |
| POST   | `/api/v1/cloud/epmp/enableAutoPolicySync` | enable auto policy sync flag |
| DELETE | `/api/v1/cloud/epmp/enroll` | Un-Enroll Symantec DHub with cloud. A system administrator account is required for this REST API. |
| GET    | `/api/v1/cloud/epmp/enroll` | Gets the enrollment status. |
| POST   | `/api/v1/cloud/epmp/enroll` | Enrolls Symantec Cloud Bridge with the cloud. |
| GET    | `/api/v1/cloud/epmp/features` | Retrieve cloud features state |
| PUT    | `/api/v1/cloud/epmp/features` | Update cloud features state |
| GET    | `/api/v1/cloud/epmp/heatmap` | Get heat map for the calling admin's domain |
| GET    | `/api/v1/cloud/epmp/hubstatus` | Get reporting hub's status |
| GET    | `/api/v1/cloud/epmp/isEnrolled` | Check if the hub on the specified server is reporting hub |
| GET    | `/api/v1/cloud/epmp/light_registration` | Fetches light registration info |
| GET    | `/api/v1/cloud/epmp/light_registration/status` | Get CDM light registration task status. |
| POST   | `/api/v1/cloud/epmp/restart-bridge-uploader-service` | Restart Bridge Uploader Service |
| GET    | `/api/v1/cloud/epmp/shouldHubRun` |  |
| GET    | `/api/v1/cloud/epmp/shouldHubRunByServerId` |  |
| POST   | `/api/v1/cloud/epmp/tenant` | Initiate cloud tenant provisioning. |

### command-queue

| Method | Endpoint | Summary |
|--------|----------|---------|
| POST   | `/api/v1/command-queue/activescan` | Sends a command from Symantec Endpoint Protection Manager to Symantec Endpoint Protection endpoints to request an active scan on the endpoint. A system administrator account is required for this REST API. |
| POST   | `/api/v1/command-queue/baseline` | Sends a command from Symantec Endpoint Protection Manager to Symantec Endpoint Protection endpoints to request that baseline application information be uploaded back to Symantec Endpoint Protection Manager. A system administrator account is required for this REST API. |
| POST   | `/api/v1/command-queue/cloudmanaged` | Sends a command from Symantec Endpoint Protection Manager to Symantec Endpoint Protection endpoints to request that those endpoints communicate directly with the cloud instead of Symantec Endpoint Protection Manager. A system administrator account is required for this REST API. |
| POST   | `/api/v1/command-queue/eoc` | Sends a command from Symantec Endpoint Protection Manager to Symantec Endpoint Protection endpoints to request an "Evidence of Compromise" scan on the endpoint. A system administrator account is required for this REST API. |
| GET    | `/api/v1/command-queue/file/{file_id}/content` | Gets the binary file content for a given file ID. A system administrator account is required for this REST API. |
| GET    | `/api/v1/command-queue/file/{file_id}/details` | Gets the details of a binary file, such as the checksum and the file size. A system administrator account is required for this REST API. |
| POST   | `/api/v1/command-queue/files` | Sends a command from Symantec Endpoint Protection Manager to Symantec Endpoint Protection endpoints to request a suspicious file be uploaded back to Symantec Endpoint Protection Manager. A system administrator account is required for this REST API. |
| POST   | `/api/v1/command-queue/fullscan` | Sends a command from Symantec Endpoint Protection Manager to Symantec Endpoint Protection endpoints to request a full scan on the endpoint. A system administrator account is required for this REST API. |
| POST   | `/api/v1/command-queue/ironcache` | Sends a command from Symantec Endpoint Protection Manager to Symantec Endpoint Protection endpoints to invalidate IRON cache entries on the endpoint. A system administrator account is required for this REST API. |
| POST   | `/api/v1/command-queue/license/override` | Sends a command from Symantec Endpoint Protection Manager to Symantec Endpoint Protection endpoints to override the default license policy. A system administrator account is required for this REST API. |
| POST   | `/api/v1/command-queue/license/resetoverride` | Sends a command from Symantec Endpoint Protection Manager to Symantec Endpoint Protection endpoints to reset license policy to default instance. A system administrator account is required for this REST API. |
| POST   | `/api/v1/command-queue/quarantine` | Sends a command from Symantec Endpoint Protection Manager to (un)quarantine Symantec Endpoint Protection endpoints. A system administrator account is required for this REST API. |
| POST   | `/api/v1/command-queue/quarantine/files/delete/{uid}` | Sends a command from Symantec Endpoint Protection Manager to delete a file from the quarantine located on Symantec Endpoint Protection endpoints. A system administrator account is required for this REST API. |
| POST   | `/api/v1/command-queue/quarantine/files/restore/{uid}` | Sends a command from Symantec Endpoint Protection Manager to restore a file from the quarantine located on Symantec Endpoint Protection endpoints. A system administrator account is required for this REST API. |
| POST   | `/api/v1/command-queue/restart` | Sends a command from Symantec Endpoint Protection Manager to Symantec Endpoint Protection endpoints to request a reboot on the endpoint. A system administrator account is required for this REST API. |
| POST   | `/api/v1/command-queue/updatecontent` | Sends a command from SEPM to SEP endpoints to update content. A system administrator account is required for this REST API. |
| GET    | `/api/v1/command-queue/{command_id}` | Gets the details of a command status. A system administrator account is required for this REST API. |
| POST   | `/api/v1/command-queue/{command_id}/cancel` | Cancels an existing command by creating a new cancel command for clients for which the command is still pending. A system administrator account is required for this REST API. |

### computers

| Method | Endpoint | Summary |
|--------|----------|---------|
| GET    | `/api/v1/computers` | Gets the information about the computers in a specified domain. A system administrator account is required for this REST API. |
| PATCH  | `/api/v1/computers` | checks and moves a client to the specified group. A system administrator account is required for this REST API. |
| POST   | `/api/v1/computers/delete` | Deletes list of existing computers. A system administrator account is required for this REST API. |
| POST   | `/api/v1/computers/enroll` | Updates the device ID and encrypted device password for a specified computer. |
| GET    | `/api/v1/computers/enroll/{id}` | Gets the status of the enrollment job. |
| DELETE | `/api/v1/computers/{id}` | Deletes an existing computer. A system administrator account is required for this REST API. |

### content

| Method | Endpoint | Summary |
|--------|----------|---------|
| GET    | `/api/v1/content/avdef/latest` | Gets the latest revision information for antivirus definitions from Symantec Security Response. |

### domains

| Method | Endpoint | Summary |
|--------|----------|---------|
| GET    | `/api/v1/domains` | Gets a list of all accessible domains. |
| POST   | `/api/v1/domains` | Creates a new domain. |
| GET    | `/api/v1/domains/analytics` | Gets the details for the analytics domain. |
| GET    | `/api/v1/domains/name/{id}` | Gets the domain name for the specified domain ID. |
| DELETE | `/api/v1/domains/{id}` | Deletes a specified domain. |
| GET    | `/api/v1/domains/{id}` | Gets the details for a specified domain. |
| POST   | `/api/v1/domains/{id}` | Updates the status of a specified domain as enabled or disabled. |
| PUT    | `/api/v1/domains/{id}` | Updates an existing domain's information. |

### events

| Method | Endpoint | Summary |
|--------|----------|---------|
| POST   | `/api/v1/events/acknowledge/risks/{eventID}` | Acknowledges a specified event for a given risk log event ID.  The event must be from a command scan. |
| POST   | `/api/v1/events/acknowledge/{eventID}` | Acknowledges a specified event for a given event ID. |
| GET    | `/api/v1/events/critical` | Gets information related to critical events. |
| POST   | `/api/v1/events/notifications` | Posts an External Notification. |
| GET    | `/api/v1/events/notifications/{id}/report` | Gets notification report html specified by its ID, it respects the type parameter and ignore the accept header |

### ext

| Method | Endpoint | Summary |
|--------|----------|---------|
| POST   | `/api/v1/ext/groups/syncdelete` | Delete groups. A system administrator account is required for this REST API. |
| DELETE | `/api/v1/ext/groups/synchronization` | Changes the group node type back to its default value i.e Native for all the groups and temporary for default group and changes the external Reference Id back to null. |
| POST   | `/api/v1/ext/groups/synchronization` | Add/Update groups. A system administrator account is required for this REST API. |
| DELETE | `/api/v1/ext/groups/{group_id}/policies/external-communication` | Withdraw a cloud setting from a group. |
| GET    | `/api/v1/ext/groups/{group_id}/policies/external-communication` | Get cloud external communication settings for the given group |
| PUT    | `/api/v1/ext/groups/{group_id}/policies/external-communication` | Update lowbandwidth external communication settings to a given group. The values that are not specified are set to defaults |
| DELETE | `/api/v1/ext/groups/{group_id}/policies/{policy_type}` | Withdraw a cloud policy from a group. |
| GET    | `/api/v1/ext/groups/{group_id}/policies/{policy_type}` | Get a cloud Policy from a group.  |
| PUT    | `/api/v1/ext/groups/{group_id}/policies/{policy_type}` | Assign a cloud policy to a group. |
| DELETE | `/api/v1/ext/groups/{group_id}/policies/{policy_type}/{sub_type}` | Withdraw a cloud policy with sub type from a group. |
| GET    | `/api/v1/ext/groups/{group_id}/policies/{policy_type}/{sub_type}` | Get a cloud Policy from a group.  |
| PUT    | `/api/v1/ext/groups/{group_id}/policies/{policy_type}/{sub_type}` | Assign a cloud policy with sub type to a group. |
| GET    | `/api/v1/ext/{source}/groups/mycompany` | Get the 'My Company' group details. |
| GET    | `/api/v1/ext/{source}/groups/{groupId}` | Get the group information from its SAEP group ID, this is the equavalance of /api/v1/groups/{groupId} but this api takes external source group ID |

### groups

| Method | Endpoint | Summary |
|--------|----------|---------|
| GET    | `/api/v1/groups` | Gets a group list. A system administrator account is required for this REST API. |
| DELETE | `/api/v1/groups/{groupId}` | Delete a specific group. A system administrator account is required for this REST API. |
| GET    | `/api/v1/groups/{groupId}` | Get SEPM group detail information. |
| PATCH  | `/api/v1/groups/{groupId}` | Update group configuration. |
| POST   | `/api/v1/groups/{groupId}` | Create a group. A system administrator account is required for this REST API. |
| GET    | `/api/v1/groups/{groupId}/computers` | Gets the information about the computers in a specified domain and group. A system administrator account is required for this REST API. |
| GET    | `/api/v1/groups/{groupId}/external-communication` | Get external communication settings of a location in the given group. |
| PATCH  | `/api/v1/groups/{groupId}/external-communication` | Patch external communication settings to a given group. |
| PUT    | `/api/v1/groups/{groupId}/external-communication` | Add or replace external communication settings to a given group. |
| GET    | `/api/v1/groups/{groupId}/locations` | Get SEPM locations information for specific group. |
| GET    | `/api/v1/groups/{groupId}/locations/{locationId}/external-communication` | Get external communication settings of a location in the given group. |
| PATCH  | `/api/v1/groups/{groupId}/locations/{locationId}/external-communication` | Patch external communication settings to a location in the given group. |
| PUT    | `/api/v1/groups/{groupId}/locations/{locationId}/external-communication` | Update external communication settings to a location in the given group. |
| GET    | `/api/v1/groups/{groupId}/locations/{locationId}/policies` | Get policies type list which are supported by SEPM for the specific group, it will always return av, fw, lu, hi, hid adc, ips, tdad and exceptions as of now. |
| GET    | `/api/v1/groups/{groupId}/locations/{locationId}/policies/{policyType}` | Get the ID of a specific policy type that is assigned to a specific location in a specific group. |
| GET    | `/api/v1/groups/{groupId}/locations/{locationId}/quarantine` | Get quarantine policies type list which are supported by SEPM for group location's, it will always return av, fw, lu, hid, adc, ips, tdad and exceptions as of now. |
| GET    | `/api/v1/groups/{groupId}/locations/{locationId}/quarantine/{policyType}` | Get quarantine policies type list which are assigned to the specific location in specific group, the policy type can be av, fw, ips, adc, hid, lu, exceptions. |
| GET    | `/api/v1/groups/{groupId}/locations/{locationId}/settings` | Get settings of a location in the given group. |
| PATCH  | `/api/v1/groups/{groupId}/locations/{locationId}/settings` | Patch all the communication settings to a given group. |
| GET    | `/api/v1/groups/{groupId}/locations/{locationId}/xml` | Get Location XML for specified location id. A system administrator account is required for this REST API. |
| PUT    | `/api/v1/groups/{group_id}/locations/{location_id}/policies/{policy_type}` | Assign a Policy to a given location with in a group. Only location specific policies can be assigned to a location. |
| GET    | `/api/v1/groups/{group_id}/policies/{policy_type}` | Return a location independent Policy assigned to a group.  |
| PUT    | `/api/v1/groups/{group_id}/policies/{policy_type}` | Assign a location independent Policy to a group.  |
| PUT    | `/api/v1/groups/{group_id}/system-lockdown/fingerprints/{fingerprint_id}` | Assign a fingerprint list to a group for system lockdown. A system administrator account is required for this REST API. |

### gup

| Method | Endpoint | Summary |
|--------|----------|---------|
| GET    | `/api/v1/gup/status` | Gets a list of group update providers. |

### identity

| Method | Endpoint | Summary |
|--------|----------|---------|
| POST   | `/api/v1/identity/authenticate` | Authenticates and returns an access token for a valid user. |
| POST   | `/api/v1/identity/logout` | Logs off the user that is associated with a specified token. |

### licenses

| Method | Endpoint | Summary |
|--------|----------|---------|
| GET    | `/api/v1/licenses` | Retrieves all license-related information. |
| POST   | `/api/v1/licenses/add` | Imports a license file into Symantec Endpoint Protection Manager. A system administrator account is required for this REST API. |
| GET    | `/api/v1/licenses/config` | Gets the license configuration. A system administrator account is required for this REST API. |
| GET    | `/api/v1/licenses/entitlements` | Retrieves specified licenses from the licensing server, given a list of serial numbers. A system administrator account is required for this REST API. |
| GET    | `/api/v1/licenses/summary` | Returns LicenseSummary object, which contains information about license type and expiration state. A system administrator account is required for this REST API. |

### policies

| Method | Endpoint | Summary |
|--------|----------|---------|
| POST   | `/api/v1/policies/exceptions` | Creates a new exceptions policy. A system administrator account is required for this REST API. |
| DELETE | `/api/v1/policies/exceptions/{id}` | Deletes an existing Exceptions policy. A system administrator account is required for this REST API. |
| GET    | `/api/v1/policies/exceptions/{id}` | Get the exceptions policy for specified policy id. A system administrator account is required for this REST API. |
| PATCH  | `/api/v1/policies/exceptions/{id}` | Update exceptions policies by patch. A system administrator account is required for this REST API. |
| PUT    | `/api/v1/policies/exceptions/{id}` | Modify existing policy values with PUT request. A system administrator account is required for this REST API. |
| DELETE | `/api/v1/policies/firewall/{id}` | Deletes an existing Firewall policy. A system administrator account is required for this REST API. |
| GET    | `/api/v1/policies/firewall/{id}` | Get the firewall policy for specified policy id. A system administrator account is required for this REST API. |
| POST   | `/api/v1/policies/hid` | Creates a new High Intensity Detection policy. A system administrator account is required for this REST API. |
| DELETE | `/api/v1/policies/hid/{id}` | Deletes an existing HID policy. A system administrator account is required for this REST API. |
| GET    | `/api/v1/policies/hid/{id}` | Get Hid Policy payload for specified policy id. A system administrator account is required for this REST API. |
| PATCH  | `/api/v1/policies/hid/{id}` | Update policies by patch. A system administrator account is required for this REST API. |
| PUT    | `/api/v1/policies/hid/{id}` | Modify existing policy values. A system administrator account is required for this REST API. |
| GET    | `/api/v1/policies/ips/{id}` | Get Ips Policy payload for specified policy id. A system administrator account is required for this REST API. |
| POST   | `/api/v1/policies/licensing` | Creates a new SAEP licensing setting. A system administrator account is required for this REST API. |
| GET    | `/api/v1/policies/lu/{id}` | Get the LiveUpdate settings policy for specified policy id. A system administrator account is required for this REST API. |
| POST   | `/api/v1/policies/mem` | Creates a new Memory Exploit Mitigation policy. A system administrator account is required for this REST API. |
| DELETE | `/api/v1/policies/mem/{id}` | Deletes an existing MEM policy. A system administrator account is required for this REST API. |
| GET    | `/api/v1/policies/mem/{id}` | Get Mem Policy payload for specified policy id. A system administrator account is required for this REST API. |
| PATCH  | `/api/v1/policies/mem/{id}` | Update policies by patch. A system administrator account is required for this REST API. |
| PUT    | `/api/v1/policies/mem/{id}` | Modify existing policy values. A system administrator account is required for this REST API. |
| POST   | `/api/v1/policies/policy-objects/hostgroups` | Create a new Host Group Policy Component.A system administrator account is required for this REST API. |
| GET    | `/api/v1/policies/policy-objects/hostgroups/summary` | Get the host groups summary. |
| GET    | `/api/v1/policies/policy-objects/hostgroups/{id}` | Get host group policy |
| PUT    | `/api/v1/policies/policy-objects/hostgroups/{id}` | Update a Host Group Policy Component. A system administrator account is required for this REST API. |
| GET    | `/api/v1/policies/raw/{policy_type}/{id}` | Get Policy XML for specified policy id. A system administrator account is required for this REST API. |
| GET    | `/api/v1/policies/summary` | Get the policy summary for specified policy type. Also gets the list of groups to which the policies are assigned. |
| GET    | `/api/v1/policies/summary/{policy_type}` | Get the policy summary for specified policy type. Also gets the list of groups to which the policies are assigned. |
| POST   | `/api/v1/policies/tdad` | Creates a new Threat Defense for Active Directory policy. A system administrator account is required for this REST API. |
| DELETE | `/api/v1/policies/tdad/{id}` | Deletes an existing TDAD policy. A system administrator account is required for this REST API. |
| GET    | `/api/v1/policies/tdad/{id}` | Get TDAD Policy payload for specified policy id. A system administrator account is required for this REST API. |
| PATCH  | `/api/v1/policies/tdad/{id}` | Update policies by patch. A system administrator account is required for this REST API. |
| PUT    | `/api/v1/policies/tdad/{id}` | Modify existing policy values. A system administrator account is required for this REST API. |
| POST   | `/api/v1/policies/upgrade` | Creates a new Upgrade policy. A system administrator account is required for this REST API. |
| DELETE | `/api/v1/policies/upgrade/{id}` | Deletes an existing Upgrade policy. A system administrator account is required for this REST API. |
| GET    | `/api/v1/policies/upgrade/{id}` | Get Upgrade Policy payload for specified policy id. A system administrator account is required for this REST API. |
| PATCH  | `/api/v1/policies/upgrade/{id}` | Update policies by patch. A system administrator account is required for this REST API. |
| PUT    | `/api/v1/policies/upgrade/{id}` | Modify existing policy values. A system administrator account is required for this REST API. |
| POST   | `/api/v2/policies/exceptions` | Creates a new exceptions policy. A system administrator account is required for this REST API. |
| DELETE | `/api/v2/policies/exceptions/{id}` | Deletes an existing Exceptions policy. A system administrator account is required for this REST API. |
| GET    | `/api/v2/policies/exceptions/{id}` | Get the exceptions policy for specified policy id. A system administrator account is required for this REST API. |
| PATCH  | `/api/v2/policies/exceptions/{id}` | Update exceptions policies by patch. A system administrator account is required for this REST API. |
| PUT    | `/api/v2/policies/exceptions/{id}` | Modify existing policy values with PUT request. A system administrator account is required for this REST API. |

### policy-objects

| Method | Endpoint | Summary |
|--------|----------|---------|
| GET    | `/api/v1/policy-objects/fingerprints` | Gets the file fingerprint list for a specified Name as a set of hash values. A system administrator account is required for this REST API. |
| POST   | `/api/v1/policy-objects/fingerprints` | Adds a blacklist as a file fingerprint list to Symantec Endpoint Protection Manager. A system administrator account is required for this REST API. |
| DELETE | `/api/v1/policy-objects/fingerprints/{id}` | Deletes an existing blacklist, and removes it from a group to which it applies. A system administrator account is required for this REST API. |
| GET    | `/api/v1/policy-objects/fingerprints/{id}` | Gets the file fingerprint list for a specified ID as a set of hash values. A system administrator account is required for this REST API. |
| POST   | `/api/v1/policy-objects/fingerprints/{id}` | Updates an existing blacklist. A system administrator account is required for this REST API. |
| GET    | `/api/v2/policy-objects/fingerprints` | Gets the file fingerprint list for a specified Name as a set of hash values. A system administrator account is required for this REST API. |
| POST   | `/api/v2/policy-objects/fingerprints` | Adds a blacklist as a file fingerprint list to Symantec Endpoint Protection Manager. A system administrator account is required for this REST API. |
| DELETE | `/api/v2/policy-objects/fingerprints/{id}` | Deletes an existing blacklist, and removes it from a group to which it applies. A system administrator account is required for this REST API. |
| GET    | `/api/v2/policy-objects/fingerprints/{id}` | Gets the file fingerprint list for a specified ID as a set of hash values. A system administrator account is required for this REST API. |
| POST   | `/api/v2/policy-objects/fingerprints/{id}` | Updates an existing blacklist. A system administrator account is required for this REST API. |

### replication

| Method | Endpoint | Summary |
|--------|----------|---------|
| GET    | `/api/v1/replication/is_replicated` | Check whether site has replication partner. |
| POST   | `/api/v1/replication/replicatenow` | Initiates a replication for the specified replication partner. A domain administrator or system administrator account is required for this REST API. |
| GET    | `/api/v1/replication/status` | Gets replication status. |

### reporting

| Method | Endpoint | Summary |
|--------|----------|---------|
| POST   | `/api/v1/reporting/authenticate` | Authenticates and returns a PHP session token for a valid user. |

### requested-files

| Method | Endpoint | Summary |
|--------|----------|---------|
| GET    | `/api/v1/requested-files/{sha256}/content` | Gets the binary file content for a given SHA value. A system administrator account is required for this REST API. |

### sessions

| Method | Endpoint | Summary |
|--------|----------|---------|
| GET    | `/api/v1/sessions/currentuser` | Gets the current usertoken object |

### stats

| Method | Endpoint | Summary |
|--------|----------|---------|
| GET    | `/api/v1/stats/autoresolved/{reportType}/{startTime}/to/{endTime}` | Gets a list of threats that were automatically resolved. Threats include viruses, spyware, and risks. |
| GET    | `/api/v1/stats/client/content` | Gets a list of clients for a group by content version. |
| GET    | `/api/v1/stats/client/content/sources` | Gets a list and count of client groups by content download sources. |
| GET    | `/api/v1/stats/client/infection/{reportType}/{startTime}/to/{endTime}` | Gets a list and count for a specified time range of infected clients. |
| GET    | `/api/v1/stats/client/malware/{reportType}/{startTime}/to/{endTime}` | Gets a list for a specified time range of clients reporting malware events. |
| GET    | `/api/v1/stats/client/onlinestatus` | Gets a list and count of the online and offline clients. |
| GET    | `/api/v1/stats/client/risk/{startTime}/to/{endTime}` | Gets a list for a specified time range the risk distribution by protection technology information for the given time range. |
| GET    | `/api/v1/stats/client/version` | Gets a list and count of clients by client product version. |
| GET    | `/api/v1/stats/licenses` | Returns license usage for last four quarters. |
| GET    | `/api/v1/stats/threat` | Gets threat statistics. |

### tdad

| Method | Endpoint | Summary |
|--------|----------|---------|
| DELETE | `/api/v1/tdad` | Deletes all Threat Defense for Active Directory data. |
| GET    | `/api/v1/tdad` | Gets all Threat Defense for Active Directory policies. |
| PATCH  | `/api/v1/tdad` | Updates an existing Threat Defense for Active Directory policy. |
| POST   | `/api/v1/tdad` | Creates a new TDAD Global. |
| PUT    | `/api/v1/tdad` | Updates an existing Threat Defense for Active Directory policy. |
| DELETE | `/api/v1/tdad/{adDomainUid}/{policyUid}` | Deletes the Threat Defense for Active Directory data for the specified Active Directory domain UID and policy UID. |
| GET    | `/api/v1/tdad/{adDomainUid}/{policyUid}` | Gets a Threat Defense for Active Directory policy for the specified Active Directory domain UID and policy UID. |

### version

| Method | Endpoint | Summary |
|--------|----------|---------|
| GET    | `/api/v1/version` | Gets the current version of Symantec Endpoint Protection Manager. |

---

## Schemas

### administrators

- **`AddAdminEntry`** — required: adminType, authenticationMethod, emailAddress, lockTimeThreshold, loginAttemptThreshold, loginName, password
- **`AdminEntry`** — required: emailAddress, lockTimeThreshold, loginAttemptThreshold
- **`AdminSummaryDetails`** — required: adminType, attemptThreshold, authenticationMethod, companyName, creationTime, email, enabled, failedLoginCount, lastLoginTime, lastLogonIP, lastPasswordChanged, lockStatus, lockTimeThreshold, loginName, onlineStatus, passwordExpiresIn
- **`DbPasswordCertPair`** — required: none
- **`DirectoryServerIntegrationConfiguration`** — required: none
- **`LicenseSummary`** — required: none
- **`LicenseSummaryDetails`** — required: none
- **`PasswordSettings`** — required: none
- **`SepmDatabase`** — required: none
- **`Server`** — required: none
- **`TdadServerCertificate`** — required: none
- **`TdadServerDetails`** — required: none
- **`administrators_UserPermission`** — required: none
- **`administrators_UserToken`** — required: adminId, token

### blacklist

- **`BlacklistPayload`** — required: data, description, domainId, hashType, name
- **`BlacklistPayloadMapStringString`** — required: data, description, domainId, hashType, name
- **`BlacklistPayloadString`** — required: data, description, domainId, hashType, name
- **`FingerPrintList`** — required: data, description, groupIds, hashType, id, name, source

### cloud

- **`AdminAccountCreationPayload`** — required: domain_id, email_address, first_name, last_name, pin
- **`AssetSyncResetStatus`** — required: none
- **`CdmRegistrationTaskStatusSummary`** — required: none
- **`CloudAccountVerificationPayload`** — required: email_address, first_name, last_name
- **`EPMPUserCredential`** — required: clientID, clientId, clientSecret, epmpCustomerId, epmpDomainId
- **`EnrollmentStatus`** — required: none
- **`EpmpFeatureStateTO`** — required: none
- **`HubAgentStatus`** — required: none
- **`Supplier`** — required: none
- **`SupplierMapStringString`** — required: none

### commands

- **`BinaryFile`** — required: checksum, fileSize, id
- **`CloudModeCommandData`** — required: targets
- **`CommandStatusDetail`** — required: none
- **`CommandTargets`** — required: none
- **`FingerprintlistPayload`** — required: none
- **`LicenseEntitlements`** — required: certificate, signed_payload
- **`RestartPayload`** — required: prompt_type, schedule_type

### computers

- **`BulkResponse`** — required: none
- **`Computer`** — required: none
- **`ComputerPayload`** — required: deviceId, devicePassword, hardwareKey, publicKey
- **`DomainSummary`** — required: none

### content

- **`LatestRevisionInfo`** — required: contentName, publishedBySEPM, publishedBySymantec

### domains

- **`Domain`** — required: none
- **`DomainAddEditTO`** — required: allowNeverExpiresPasswords, allowUsersToSaveCredentials, deleteOldClients, deleteOldClientsDays, deleteOldVDIClients, deleteOldVDIClientsDays, showBanner
- **`DomainEntry`** — required: allowNeverExpiringPasswords, allowSavingCredentials, deleteIdleClients, deleteIdleNpvdiClients, displayLogonBanner, domainId, domainName, maxClientIdleTimeInDays, maxNpvdiClientIdleTimeInDays
- **`NameValueTO`** — required: none

### events

- **`CriticalEventsInfo`** — required: acknowledged, eventDateTime, eventId, message, subject
- **`CriticalEventsResponse`** — required: criticalEventsInfoList, lastUpdated, totalUnacknowledgedMessages
- **`Notification`** — required: hyperlink, message, name, subject

### groups

- **`ClientLog`** — required: none
- **`CloudServerCertificate`** — required: none
- **`CommunicationSettings`** — required: none
- **`ContentThreshold`** — required: none
- **`ExternalCommunicationSettings`** — required: none
- **`GeneralSettings`** — required: none
- **`Group`** — required: name
- **`GroupPayload`** — required: name
- **`GroupSettingsConfiguration`** — required: none
- **`Immediate`** — required: none
- **`LiveUpdateContentSettings`** — required: none
- **`LowBandwidthConfiguration`** — required: none
- **`MetadataAttributes`** — required: id, name
- **`PasswordProtection`** — required: none
- **`PrivateCloudConfiguration`** — required: none
- **`PrivateCloudServer`** — required: none
- **`PrivateCloudServerGroup`** — required: none
- **`Proxy`** — required: none
- **`Restart`** — required: none
- **`Schedule`** — required: none
- **`SecuritySettings`** — required: none
- **`SepmLocationDetails`** — required: location_id, location_name, location_rules_xml
- **`ServerListSummary`** — required: none
- **`Settings`** — required: none
- **`SettingsExternalCommunicationSettingsObject`** — required: none
- **`SettingsGroupSettingsConfigurationObject`** — required: none
- **`TamperProtection`** — required: none
- **`Telemetry`** — required: none
- **`UserPauseTillSchedule`** — required: none
- **`groups_EndpointNotification`** — required: none

### gup

- **`GUPData`** — required: none

### identity

- **`UserCredential`** — required: domain, password, username
- **`UserRole`** — required: bitMask, title
- **`identity_UserPermission`** — required: none
- **`identity_UserToken`** — required: adminId, token

### policies

- **`AdapterConfiguration`** — required: none
- **`Advanced`** — required: none
- **`ApplicationConfiguration`** — required: name
- **`CenteralLuServer`** — required: none
- **`ConnectionConfiguration`** — required: none
- **`CustomGroupRule`** — required: none
- **`CustomIPSSignatureRule`** — required: none
- **`CustomVariableRule`** — required: none
- **`DnsHost`** — required: none
- **`DnsName`** — required: none
- **`ExceptionThreat`** — required: id, name
- **`ExceptionsApplicationToMonitor`** — required: name
- **`ExceptionsConfiguration`** — required: none
- **`ExceptionsConfigurationV2`** — required: none
- **`ExceptionsFile`** — required: sha2
- **`ExceptionsFingerprint`** — required: algorithm, value
- **`ExceptionsLinuxConfiguration`** — required: none
- **`ExceptionsLockedOptions`** — required: none
- **`ExceptionsMacConfiguration`** — required: none
- **`ExceptionsRuleApplication`** — required: processfile
- **`ExceptionsRuleBlacklist`** — required: action, processfile
- **`ExceptionsRuleCertificate`** — required: signature_fingerprint
- **`ExceptionsRuleDirectory`** — required: directory, pathvariable
- **`ExceptionsRuleDnsHostBlacklist`** — required: action, processfile
- **`ExceptionsRuleDomain`** — required: domain
- **`ExceptionsRuleExtensionList`** — required: extensions
- **`ExceptionsRuleFile`** — required: path, pathvariable
- **`ExceptionsRuleKnownRisk`** — required: threat
- **`ExceptionsRuleLinuxDirectory`** — required: directory, pathvariable
- **`ExceptionsRuleMacFile`** — required: path, pathvariable
- **`ExceptionsRuleNonPEFile`** — required: file
- **`ExceptionsRuleState`** — required: source
- **`ExplicitGroupUpdateProviders`** — required: none
- **`ExplicitMapping`** — required: none
- **`File`** — required: none
- **`FirewallConfiguration`** — required: none
- **`FirewallRuleConfiguration`** — required: name, uid
- **`FtpProxy`** — required: none
- **`GroupLocationSummary`** — required: none
- **`GroupUpdateProvider`** — required: none
- **`HidConfiguration`** — required: none
- **`HostNameData`** — required: none
- **`HttpProxy`** — required: none
- **`IPSConfiguration`** — required: none
- **`IPSRuleState`** — required: source
- **`IPSSignatureRule`** — required: none
- **`IPv4Subnet`** — required: none
- **`IntegerRange`** — required: none
- **`IpData`** — required: none
- **`IpRange`** — required: ip_end, ip_start
- **`IpRangeConfiguration`** — required: none
- **`IpV4`** — required: none
- **`IpV4Range`** — required: none
- **`IpV4Subnet`** — required: none
- **`IpV6`** — required: none
- **`IpV6Range`** — required: none
- **`IpV6Subnet`** — required: none
- **`IpsAndHostsRule`** — required: none
- **`Key`** — required: none
- **`KeyName`** — required: none
- **`KeyValue`** — required: none
- **`LicensingPolicyPayload`** — required: certificate, signed_payload
- **`LuConfiguration`** — required: none
- **`LuSchedule`** — required: none
- **`LuServer`** — required: none
- **`Mac`** — required: none
- **`MacFirewallConfiguration`** — required: none
- **`MemConfiguration`** — required: none
- **`MemLockedOptions`** — required: none
- **`MultipleGroupUpdateProviders`** — required: none
- **`OperatingSystemsRule`** — required: none
- **`PagePolicySummary`** — required: none
- **`PeerToPeerAuthConfiguration`** — required: none
- **`PepExceptionElement`** — required: path
- **`PepThreatRuleElement`** — required: id, name
- **`Platform`** — required: none
- **`PolicyExceptionsConfigurationExceptionsLockedOptions`** — required: name
- **`PolicyExceptionsConfigurationV2ExceptionsLockedOptions`** — required: name
- **`PolicyFirewallConfigurationObject`** — required: name
- **`PolicyHidConfigurationObject`** — required: name
- **`PolicyIPSConfigurationObject`** — required: name
- **`PolicyLuConfigurationObject`** — required: name
- **`PolicyMemConfigurationMemLockedOptions`** — required: name
- **`PolicySummary`** — required: name
- **`PolicyTdadConfigurationObject`** — required: name
- **`PolicyUpgradeConfigurationObject`** — required: name
- **`PortConfiguration`** — required: none
- **`ProxyConfiguration`** — required: none
- **`RawPolicy`** — required: none
- **`RegistryRule`** — required: none
- **`RepDiscoveredRule`** — required: none
- **`RepPrevalenceRule`** — required: none
- **`RuleSet`** — required: none
- **`RuleState`** — required: none
- **`Sources`** — required: none
- **`TdadConfiguration`** — required: none
- **`TdadElement`** — required: none
- **`TimeSlotConfiguration`** — required: none
- **`UpgradeConfiguration`** — required: none
- **`UpgradeSchedule`** — required: none
- **`WeekDays`** — required: none
- **`policies_EndpointNotification`** — required: none
- **`policies_Policy`** — required: name

### replication

- **`ReplicationAllStatus`** — required: code
- **`ReplicationPartnerStatus`** — required: id, lastRunTime, lastSuccessfulRunTime, location, name, nextRunTime, status_code
- **`ReplicationStatus`** — required: id, replicationPartnerStatusList, siteLocation, siteName
- **`ReplicationStatusResponse`** — required: none

### reporting

- **`ReportingInfo`** — required: none
- **`UserPassword`** — required: password

### statistics

- **`AutoResolvedAttacks`** — required: autoResolvedAttacksCount, epochTime
- **`AutoResolvedAttacksResponse`** — required: getautoResolvedAttacks, lastUpdated
- **`ClientDefStatus`** — required: clientsCount, version
- **`ClientDefStatusResponse`** — required: clientDefStatusList, lastUpdated
- **`ClientVersion`** — required: clientsCount, formattedVersion, version
- **`ClientVersionResponse`** — required: clientVersionList, lastUpdated
- **`ClientsOnlineStats`** — required: clientsCount, status
- **`ClientsOnlineStatsResponse`** — required: clientCountStatsList, lastUpdated
- **`ContentDownloadSource`** — required: clientCount, sourceKey, sourceName
- **`ContentDownloadSourceResponse`** — required: downloadSources, lastUpdated
- **`InfectedClientStats`** — required: none
- **`InfectedClientStatsResponse`** — required: none
- **`LicenseUsage`** — required: none
- **`MalwareClientStats`** — required: clientsCount, epochTime
- **`MalwareClientStatsResponse`** — required: lastUpdated, malwareClientStats
- **`RiskDistributionStats`** — required: protectionEnabledClientCount, protectionName, riskCount
- **`RiskDistributionStatsResponse`** — required: riskDistributionStats

### tdad

- **`AdDomainPolicies`** — required: none
- **`User`** — required: none
- **`tdad_Policy`** — required: none

### Common

- **`Annotation`** — required: none
- **`AsyncContext`** — required: none
- **`BufferedReader`** — required: none
- **`ClassLoader`** — required: none
- **`Enumeration`** — required: none
- **`EnumerationLocale`** — required: none
- **`EnumerationServlet`** — required: none
- **`EnumerationString`** — required: none
- **`FilterRegistration`** — required: none
- **`GroupSummary`** — required: none
- **`Host`** — required: none
- **`HostConfiguration`** — required: none
- **`HostGroup`** — required: hosts, name
- **`HostGroupSummary`** — required: name
- **`HttpServletMapping`** — required: none
- **`InputStream`** — required: none
- **`JspConfigDescriptor`** — required: none
- **`JspPropertyGroupDescriptor`** — required: none
- **`Locale`** — required: none
- **`Module`** — required: none
- **`ModuleDescriptor`** — required: none
- **`ModuleLayer`** — required: none
- **`Package`** — required: none
- **`PageCommandStatusDetail`** — required: none
- **`PageHostGroupSummary`** — required: none
- **`PageObject`** — required: none
- **`Part`** — required: none
- **`Principal`** — required: none
- **`PrintWriter`** — required: none
- **`ServletRegistration`** — required: none
- **`ServletRequest`** — required: none
- **`ServletResponse`** — required: none
- **`SessionCookieConfig`** — required: none
- **`Sort`** — required: none
- **`StringBuffer`** — required: none
- **`TaglibDescriptor`** — required: none
- **`blacklist_Cookie`** — required: none
- **`blacklist_HttpServletRequest`** — required: none
- **`blacklist_HttpSession`** — required: none
- **`blacklist_HttpSessionContext`** — required: none
- **`blacklist_ServletContext`** — required: none
- **`blacklist_ServletInputStream`** — required: none
- **`blacklist_ServletOutputStream`** — required: none
- **`cloud_HttpServletResponse`** — required: none
- **`commands_Page`** — required: none
- **`groups_Cookie`** — required: none
- **`groups_HttpServletRequest`** — required: none
- **`groups_HttpServletResponse`** — required: none
- **`groups_HttpSession`** — required: none
- **`groups_HttpSessionContext`** — required: none
- **`groups_Page`** — required: none
- **`groups_ServletContext`** — required: none
- **`groups_ServletInputStream`** — required: none
- **`groups_ServletOutputStream`** — required: none

---

## Notes

- Categories with **v2 API** paths: policies, policy-objects

- Definitions referencing Java servlet types (`HttpServletRequest`, `ServletRequest`, `ServletContext`, etc.) are internal SEPM plumbing and **not part of the actual API contract**. They appear as parameters marked "Only used internally".
- The `basePath` is `/sepm/api/v1` and the full URL pattern is `https://{SEPM_HOST}:{PORT}/sepm/api/v1/...`
