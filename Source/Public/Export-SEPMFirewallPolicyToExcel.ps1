function Export-SEPMFirewallPolicyToExcel {
    <#
    .SYNOPSIS
        Exports firewall policy data to an Excel workbook with 3 sheets.
    .DESCRIPTION
        Produces an XLSX file containing Policies, FirewallRules, and PolicyAssignments
        sheets from a SEPM.PolicySnapshot. Works standalone or via pipeline.
    .PARAMETER Path
        The output XLSX file path. Must have .xlsx extension and a valid parent directory.
    .PARAMETER Snapshot
        A SEPM.PolicySnapshot object. Accepts pipeline input. If omitted, calls
        Get-SEPMPolicySnapshot -PolicyType fw internally.
    .PARAMETER SkipCertificateCheck
        Bypasses certificate validation for self-signed SEPM certificates.
    .EXAMPLE
        Export-SEPMFirewallPolicyToExcel -Path ./fw.xlsx

        Fetches a new snapshot and exports firewall policies to Excel.
    .EXAMPLE
        $snap | Export-SEPMFirewallPolicyToExcel -Path ./fw.xlsx

        Exports an existing snapshot via pipeline.
#>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({
            if (-Not (Split-Path $_ -Parent | Test-Path)) {
                throw "Directory of '$_' does not exist"
            }
            if (-Not ($_ -match '\.xlsx$')) {
                throw "File '$_' does not have the .xlsx extension"
            }
            return $true
        })]

        [string]
        $Path,

        [Parameter(ValueFromPipeline = $true)]
        [AllowNull()]
        [PSObject]
        $Snapshot,

        [Parameter()]
        [switch]
        $SkipCertificateCheck
    )

    begin {
        $excelParams = @{
            ClearSheet   = $true
            BoldTopRow   = $true
            AutoSize     = $true
            FreezeTopRow = $true
            AutoFilter   = $true
        }
    }

    process {
        if (-not $Snapshot) {
            $Snapshot = Get-SEPMPolicySnapshot -PolicyType fw
        }

        # Sheet 1: Policies
        $policiesSheet = @()
        foreach ($policy in $Snapshot.FW.Policies) {
            $cfg = $policy.configuration
            $policiesSheet += [PSCustomObject]@{
                PolicyName          = $policy.name
                Enabled             = $policy.enabled
                Description         = $policy.desc
                LastModified        = $policy.lastmodifiedtime
                EnforcedRulesCount  = if ($cfg.enforced_rules) { $cfg.enforced_rules.Count } else { 0 }
                BaselineRulesCount  = if ($cfg.baseline_rules) { $cfg.baseline_rules.Count } else { 0 }
                WindowsFirewall     = $cfg.windows_firewall
                SmartDHCP           = $cfg.smart_dhcp
                SmartDNS            = $cfg.smart_dns
                SmartWINS           = $cfg.smart_wins
                DoS                 = $cfg.dos
                Autoblock           = $cfg.autoblock
                AutoblockDuration   = $cfg.autoblock_duration
                StealthWeb          = $cfg.stealth_web
                AntiIPSpoofing      = $cfg.antiIP_spoofing
                AntiMacSpoofing     = $cfg.antimac_spoofing
                HideOS              = $cfg.hide_os
                PortScan            = $cfg.port_scan
                ReverseDNS          = $cfg.reverse_dns
                NetBiosProtection   = $cfg.netbios_protection
                TokenRingTraffic    = $cfg.token_ring_traffic
            }
        }
        $policiesSheet | Export-Excel -Path $Path -WorksheetName 'Policies' @excelParams

        # Sheet 2: FirewallRules
        $rulesSheet = @()
        foreach ($policy in $Snapshot.FW.Policies) {
            $allRules = @()
            if ($policy.configuration.enforced_rules) {
                $policy.configuration.enforced_rules | ForEach-Object {
                    $_ | Add-Member -NotePropertyName '_RuleType' -NotePropertyValue 'Enforced' -Force
                    $allRules += $_
                }
            }
            if ($policy.configuration.baseline_rules) {
                $policy.configuration.baseline_rules | ForEach-Object {
                    $_ | Add-Member -NotePropertyName '_RuleType' -NotePropertyValue 'Baseline' -Force
                    $allRules += $_
                }
            }
            foreach ($rule in $allRules) {
                $conns = if ($rule.connections) { $rule.connections } else { @() }
                $connectionsJson = Flatten-Connections -Connections $conns
                $connectionsDetails = Format-ConnectionsDetails -Connections $conns
                $adaptersStr = Flatten-Adapters -Adapters $rule.adapters
                $appsStr = Flatten-Apps -Applications $rule.applications
                $hostsStr = Flatten-Hosts -Hosts $rule.hosts

                $rulesSheet += [PSCustomObject]@{
                    RuleType             = $rule._RuleType
                    PolicyName           = $policy.name
                    PolicyEnabled        = $policy.enabled
                    RuleName             = $rule.name
                    RuleUID              = $rule.uid
                    Action               = $rule.action
                    Severity             = $rule.severity
                    RuleEnabled          = $rule.rulestate.enabled
                    Connections          = $connectionsJson
                    ConnectionsDetails   = $connectionsDetails
                    Adapters             = $adaptersStr
                    Applications         = $appsStr
                    Hosts                = $hostsStr
                    LogAction            = $rule.log_action
                    PacketCapture        = $rule.packet_capture
                    EmailAlert           = $rule.email_alert
                    ScreenSaver          = $rule.screen_saver
                    TimeSlots            = $rule.time_slots
                    RuleDescription      = $rule.desc
                }
            }
        }
        $rulesSheet | Export-Excel -Path $Path -WorksheetName 'FirewallRules' @excelParams

        # Sheet 3: PolicyAssignments
        $assignmentsSheet = @()
        foreach ($policy in $Snapshot.FW.Policies) {
            $summary = $Snapshot.FW.Summary | Where-Object { $_.name -eq $policy.name } | Select-Object -First 1
            if (-not $summary -or -not $summary.assignedtolocations) { continue }
            foreach ($assignment in $summary.assignedtolocations) {
                $locNames = @()
                if ($assignment.locationIds) {
                    foreach ($locId in $assignment.locationIds) {
                        $locName = $Snapshot.LocationMap[$locId]
                        if ($locName) { $locNames += $locName }
                    }
                }
                $assignmentsSheet += [PSCustomObject]@{
                    PolicyName     = $policy.name
                    PolicyEnabled  = $policy.enabled
                    GroupFullPath  = $assignment.groupNameFullPath
                    Locations      = $locNames -join '; '
                }
            }
        }
        $assignmentsSheet | Export-Excel -Path $Path -WorksheetName 'PolicyAssignments' @excelParams
    }
}
