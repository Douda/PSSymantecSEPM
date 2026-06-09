[CmdletBinding()]
param()

Describe 'Export-SEPMFirewallPolicyToExcel' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context 'Tracer bullet: standalone mode' {
        BeforeAll {
            $locMap = @{ 'loc-001' = 'Default'; 'loc-002' = 'VPN' }

            $fwPolicy1 = New-DummyFirewallPolicy -PolicyName 'FW Policy 1'
            $fwPolicy1.configuration.enforced_rules = @(
                (New-DummyFirewallRule -Name 'Allow HTTP' -Action 'ALLOW' -Uid 'AAA001'),
                (New-DummyFirewallRule -Name 'Block SSH'  -Action 'BLOCK' -Uid 'AAA002')
            )
            $fwPolicy1.configuration.baseline_rules = @(
                (New-DummyFirewallRule -Name 'Baseline Block All' -Action 'BLOCK' -Uid 'BBB001')
            )

            $snapshot = New-DummyPolicySnapshot -FWPolicies @($fwPolicy1) -LocationMap $locMap

            Mock Get-SEPMPolicySnapshot -ModuleName PSSymantecSEPM { return $snapshot }
        }

        It 'writes a valid XLSX file with 3 sheets' {
            $xlsxPath = Join-Path -Path 'TestDrive:' -ChildPath 'fw.xlsx'
            Export-SEPMFirewallPolicyToExcel -Path $xlsxPath

            $xlsxPath | Should -Exist
            $sheetNames = Get-ExcelSheetInfo -Path $xlsxPath | Select-Object -ExpandProperty Name
            $sheetNames | Should -Contain 'Policies'
            $sheetNames | Should -Contain 'FirewallRules'
            $sheetNames | Should -Contain 'PolicyAssignments'
        }
    }

    Context 'Policies sheet data' {
        BeforeAll {
            $locMap = @{ 'loc-001' = 'Default' }
            $fwPolicy1 = New-DummyFirewallPolicy -PolicyName 'Test FW Policy'
            $fwPolicy1.desc = 'A test description'
            $fwPolicy1.lastmodifiedtime = 1700000000000
            $fwPolicy1.configuration.enforced_rules = @(
                (New-DummyFirewallRule -Name 'Rule 1' -Action 'ALLOW' -Uid 'POL001'),
                (New-DummyFirewallRule -Name 'Rule 2' -Action 'BLOCK' -Enabled $false -Uid 'POL002')
            )
            $fwPolicy1.configuration.baseline_rules = @(
                (New-DummyFirewallRule -Name 'Base Rule' -Action 'BLOCK' -Uid 'POLBASE')
            )
            $fwPolicy1.configuration.windows_firewall = 'NO_ACTION'
            $fwPolicy1.configuration.smart_dhcp = $true
            $fwPolicy1.configuration.smart_dns  = $false
            $fwPolicy1.configuration.smart_wins = $true
            $fwPolicy1.configuration.dos        = $false
            $fwPolicy1.configuration.autoblock  = $true
            $fwPolicy1.configuration.autoblock_duration = 600
            $fwPolicy1.configuration.stealth_web       = $false
            $fwPolicy1.configuration.antiIP_spoofing   = $true
            $fwPolicy1.configuration.antimac_spoofing  = $false
            $fwPolicy1.configuration.hide_os           = $true
            $fwPolicy1.configuration.port_scan         = $false
            $fwPolicy1.configuration.reverse_dns       = $true
            $fwPolicy1.configuration.netbios_protection = $false
            $fwPolicy1.configuration.token_ring_traffic = $false

            $snapshot = New-DummyPolicySnapshot -FWPolicies @($fwPolicy1) -LocationMap $locMap

            Mock Get-SEPMPolicySnapshot -ModuleName PSSymantecSEPM { return $snapshot }

            $script:polXlsxPath = Join-Path -Path 'TestDrive:' -ChildPath 'fw-policies.xlsx'
            Export-SEPMFirewallPolicyToExcel -Path $script:polXlsxPath
            $script:polSheet = Import-Excel -Path $script:polXlsxPath -WorksheetName 'Policies'
        }

        It 'has all 21 required column headers' {
            $headers = $script:polSheet[0].PSObject.Properties.Name
            $expected = @(
                'PolicyName', 'Enabled', 'Description', 'LastModified',
                'EnforcedRulesCount', 'BaselineRulesCount',
                'WindowsFirewall', 'SmartDHCP', 'SmartDNS', 'SmartWINS',
                'DoS', 'Autoblock', 'AutoblockDuration', 'StealthWeb',
                'AntiIPSpoofing', 'AntiMacSpoofing', 'HideOS',
                'PortScan', 'ReverseDNS', 'NetBiosProtection', 'TokenRingTraffic'
            )
            foreach ($col in $expected) { $headers | Should -Contain $col }
            $headers.Count | Should -Be 21
        }

        It 'has correct policy name and description' {
            $script:polSheet[0].PolicyName  | Should -Be 'Test FW Policy'
            $script:polSheet[0].Description | Should -Be 'A test description'
            $script:polSheet[0].Enabled     | Should -Be $true
        }

        It 'has correct rule counts' {
            $script:polSheet[0].EnforcedRulesCount | Should -Be 2
            $script:polSheet[0].BaselineRulesCount | Should -Be 1
        }

        It 'has correct boolean config values' {
            $row = $script:polSheet[0]
            $row.WindowsFirewall | Should -Be 'NO_ACTION'
            $row.SmartDHCP       | Should -Be $true
            $row.SmartDNS        | Should -Be $false
            $row.SmartWINS       | Should -Be $true
            $row.DoS             | Should -Be $false
            $row.Autoblock       | Should -Be $true
            $row.AutoblockDuration | Should -Be 600
            $row.StealthWeb      | Should -Be $false
            $row.AntiIPSpoofing  | Should -Be $true
            $row.AntiMacSpoofing | Should -Be $false
            $row.HideOS          | Should -Be $true
            $row.PortScan        | Should -Be $false
            $row.ReverseDNS      | Should -Be $true
            $row.NetBiosProtection | Should -Be $false
            $row.TokenRingTraffic  | Should -Be $false
        }
    }

    Context 'FirewallRules sheet data' {
        BeforeAll {
            $locMap = @{ 'loc-001' = 'Default' }
            $fwPolicy1 = New-DummyFirewallPolicy -PolicyName 'FW Rules Policy'
            $fwPolicy1.configuration.enforced_rules = @(
                (New-DummyFirewallRule -Name 'Enforced Allow' -Action 'ALLOW' -Uid 'RUL001'),
                (New-DummyFirewallRule -Name 'Enforced Block' -Action 'BLOCK' -Uid 'RUL002')
            )
            $fwPolicy1.configuration.baseline_rules = @(
                (New-DummyFirewallRule -Name 'Baseline Block' -Action 'BLOCK' -Uid 'RULBASE')
            )

            $snapshot = New-DummyPolicySnapshot -FWPolicies @($fwPolicy1) -LocationMap $locMap

            Mock Get-SEPMPolicySnapshot -ModuleName PSSymantecSEPM { return $snapshot }

            $script:rulesXlsxPath = Join-Path -Path 'TestDrive:' -ChildPath 'fw-rules.xlsx'
            Export-SEPMFirewallPolicyToExcel -Path $script:rulesXlsxPath
            $script:rulesSheet = Import-Excel -Path $script:rulesXlsxPath -WorksheetName 'FirewallRules'
        }

        It 'has all 19 required column headers' {
            $headers = $script:rulesSheet[0].PSObject.Properties.Name
            $expected = @(
                'RuleType', 'PolicyName', 'PolicyEnabled', 'RuleName', 'RuleUID',
                'Action', 'Severity', 'RuleEnabled', 'Connections', 'ConnectionsDetails',
                'Adapters', 'Applications', 'Hosts', 'LogAction', 'PacketCapture',
                'EmailAlert', 'ScreenSaver', 'TimeSlots', 'RuleDescription'
            )
            foreach ($col in $expected) { $headers | Should -Contain $col }
            $headers.Count | Should -Be 19
        }

        It 'merges enforced and baseline rules into one table' {
            $script:rulesSheet.Count | Should -Be 3
            $script:rulesSheet[0].RuleType | Should -Be 'Enforced'
            $script:rulesSheet[1].RuleType | Should -Be 'Enforced'
            $script:rulesSheet[2].RuleType | Should -Be 'Baseline'
        }

        It 'has correct rule metadata' {
            $r = $script:rulesSheet[0]
            $r.PolicyName    | Should -Be 'FW Rules Policy'
            $r.PolicyEnabled | Should -Be $true
            $r.RuleName      | Should -Be 'Enforced Allow'
            $r.RuleUID       | Should -Be 'RUL001'
            $r.Action        | Should -Be 'ALLOW'
            $r.Severity      | Should -Be 3
            $r.RuleEnabled   | Should -Be $true
            $r.LogAction     | Should -Be 0
            $r.PacketCapture | Should -Be $false
            $r.EmailAlert    | Should -Be $false
            $r.ScreenSaver   | Should -Be 'ANY'
        }
    }

    Context 'PolicyAssignments sheet data' {
        BeforeAll {
            $locMap = @{ 'loc-aaa' = 'Default'; 'loc-bbb' = 'VPN'; 'loc-ccc' = 'Office' }
            $fwPolicy1 = New-DummyFirewallPolicy -PolicyName 'Assigned FW Policy'

            $summary = New-DummyPolicySummary -PolicyName 'Assigned FW Policy' -PolicyType 'fw'
            $summary.assignedtolocations = @(
                [PSCustomObject]@{ groupId = 'group-1'; locationIds = @('loc-aaa', 'loc-bbb'); defaultLocationId = 'loc-aaa'; groupNameFullPath = 'My Company\Workstations' },
                [PSCustomObject]@{ groupId = 'group-2'; locationIds = @('loc-ccc'); defaultLocationId = 'loc-ccc'; groupNameFullPath = 'My Company\Servers' }
            )

            $snapshot = New-DummyPolicySnapshot -FWPolicies @($fwPolicy1) -FWSummary @($summary) -LocationMap $locMap

            Mock Get-SEPMPolicySnapshot -ModuleName PSSymantecSEPM { return $snapshot }

            $script:assignXlsxPath = Join-Path -Path 'TestDrive:' -ChildPath 'fw-assign.xlsx'
            Export-SEPMFirewallPolicyToExcel -Path $script:assignXlsxPath
            $script:assignSheet = Import-Excel -Path $script:assignXlsxPath -WorksheetName 'PolicyAssignments'
        }

        It 'has all 4 required column headers' {
            $headers = $script:assignSheet[0].PSObject.Properties.Name
            $expected = @('PolicyName', 'PolicyEnabled', 'GroupFullPath', 'Locations')
            foreach ($col in $expected) { $headers | Should -Contain $col }
            $headers.Count | Should -Be 4
        }

        It 'has one row per policy-per-group assignment' {
            $script:assignSheet.Count | Should -Be 2
        }

        It 'joins multiple location names with semicolon' {
            $script:assignSheet[0].PolicyName   | Should -Be 'Assigned FW Policy'
            $script:assignSheet[0].PolicyEnabled | Should -Be $true
            $script:assignSheet[0].GroupFullPath | Should -Be 'My Company\Workstations'
            $script:assignSheet[0].Locations     | Should -Be 'Default; VPN'
        }

        It 'resolves single location correctly' {
            $script:assignSheet[1].GroupFullPath | Should -Be 'My Company\Servers'
            $script:assignSheet[1].Locations     | Should -Be 'Office'
        }
    }

    Context 'Connections formatting' {
        BeforeAll {
            $locMap = @{ 'loc-001' = 'Default' }

            $fwPolicy1 = New-DummyFirewallPolicy -PolicyName 'Conn Test Policy'
            $fwPolicy1.configuration.enforced_rules = @(
                (New-DummyFirewallRule -Name 'TCP Rule'     -Action 'ALLOW' -Uid 'CONN001' -Connections @(
                    [PSCustomObject]@{ enabled = $true; direction_id = 0; protocol_ids = @(6); ports = @([PSCustomObject]@{ start = 80; end = $null; location = 'REMOTE' }) }
                )),
                (New-DummyFirewallRule -Name 'UDP Rule'     -Action 'ALLOW' -Uid 'CONN002' -Connections @(
                    [PSCustomObject]@{ enabled = $true; direction_id = 0; protocol_ids = @(17); ports = @([PSCustomObject]@{ start = 53; end = $null; location = 'LOCAL' }) }
                )),
                (New-DummyFirewallRule -Name 'ICMP Rule'    -Action 'ALLOW' -Uid 'CONN003' -Connections @(
                    [PSCustomObject]@{ enabled = $true; direction_id = 0; protocol_ids = @(1); icmp_types = @(8) }
                )),
                (New-DummyFirewallRule -Name 'ICMPv6 Rule'  -Action 'ALLOW' -Uid 'CONN004' -Connections @(
                    [PSCustomObject]@{ enabled = $true; direction_id = 0; protocol_ids = @(58); icmp_types = @(128) }
                )),
                (New-DummyFirewallRule -Name 'EtherType Rule' -Action 'ALLOW' -Uid 'CONN005' -Connections @(
                    [PSCustomObject]@{ enabled = $true; direction_id = 0; ether_type_id = 34525 }
                )),
                (New-DummyFirewallRule -Name 'Named Svc Rule' -Action 'ALLOW' -Uid 'CONN006' -Connections @(
                    [PSCustomObject]@{ enabled = $true; direction_id = 0; protocol_ids = @(6); ports = @([PSCustomObject]@{ start = 443; end = $null; location = 'REMOTE' }); svc_name = 'HTTPS' }
                )),
                (New-DummyFirewallRule -Name 'Fragmented Rule' -Action 'ALLOW' -Uid 'CONN007' -Connections @(
                    [PSCustomObject]@{ enabled = $true; direction_id = 0; ip_fragmented_only = $true }
                )),
                (New-DummyFirewallRule -Name 'Mixed Rule' -Action 'ALLOW' -Uid 'CONN008' -Connections @(
                    [PSCustomObject]@{ enabled = $true; direction_id = 1; protocol_ids = @(6); ports = @([PSCustomObject]@{ start = 5353; end = $null; location = 'LOCAL' }) },
                    [PSCustomObject]@{ enabled = $true; direction_id = 0; protocol_ids = @(17); ports = @([PSCustomObject]@{ start = 53; end = $null; location = 'REMOTE' }) }
                ))
            )
            $fwPolicy1.configuration.baseline_rules = @()

            $snapshot = New-DummyPolicySnapshot -FWPolicies @($fwPolicy1) -LocationMap $locMap

            Mock Get-SEPMPolicySnapshot -ModuleName PSSymantecSEPM { return $snapshot }

            $script:connXlsxPath = Join-Path -Path 'TestDrive:' -ChildPath 'fw-conn.xlsx'
            Export-SEPMFirewallPolicyToExcel -Path $script:connXlsxPath
            $script:connSheet = Import-Excel -Path $script:connXlsxPath -WorksheetName 'FirewallRules'
        }

        It 'Connections column shows raw JSON of enabled connections' {
            $row = $script:connSheet | Where-Object { $_.RuleUID -eq 'CONN001' }
            $row.Connections | Should -Not -BeNullOrEmpty
            $row.Connections | Should -Match '80'
            $row.Connections | Should -Match 'REMOTE'
        }

        It 'ConnectionsDetails shows TCP outbound format' {
            $row = $script:connSheet | Where-Object { $_.RuleUID -eq 'CONN001' }
            $row.ConnectionsDetails | Should -BeLike '*TCP*'
            $row.ConnectionsDetails | Should -BeLike '*80*'
        }

        It 'ConnectionsDetails shows UDP format' {
            $row = $script:connSheet | Where-Object { $_.RuleUID -eq 'CONN002' }
            $row.ConnectionsDetails | Should -BeLike '*UDP*'
            $row.ConnectionsDetails | Should -BeLike '*53*'
        }

        It 'ConnectionsDetails shows ICMP format' {
            $row = $script:connSheet | Where-Object { $_.RuleUID -eq 'CONN003' }
            $row.ConnectionsDetails | Should -BeLike '*ICMP*type 8*'
        }

        It 'ConnectionsDetails shows ICMPv6 format' {
            $row = $script:connSheet | Where-Object { $_.RuleUID -eq 'CONN004' }
            $row.ConnectionsDetails | Should -BeLike '*ICMPv6*type 128*'
        }

        It 'ConnectionsDetails shows ether-type format' {
            $row = $script:connSheet | Where-Object { $_.RuleUID -eq 'CONN005' }
            $row.ConnectionsDetails | Should -BeLike '*ether*'
            $row.ConnectionsDetails | Should -BeLike '*34525*'
        }

        It 'ConnectionsDetails shows named service' {
            $row = $script:connSheet | Where-Object { $_.RuleUID -eq 'CONN006' }
            $row.ConnectionsDetails | Should -BeLike '*HTTPS*'
        }

        It 'ConnectionsDetails shows fragmented-only' {
            $row = $script:connSheet | Where-Object { $_.RuleUID -eq 'CONN007' }
            $row.ConnectionsDetails | Should -BeLike '*fragmented*'
        }

        It 'ConnectionsDetails joins multiple connections with semicolon' {
            $row = $script:connSheet | Where-Object { $_.RuleUID -eq 'CONN008' }
            $row.ConnectionsDetails | Should -Match ';'
        }
    }

    Context 'Truncation at 30 items' {
        BeforeAll {
            $locMap = @{ 'loc-001' = 'Default' }
            $adapters = 1..35 | ForEach-Object { [PSCustomObject]@{ name = "Adapter $_"; type = 'ETHERNET'; uid = "ADAPT$_" } }
            $apps     = 1..35 | ForEach-Object { [PSCustomObject]@{ name = "app$_.exe" } }
            $hosts    = 1..35 | ForEach-Object { [PSCustomObject]@{ location = 'REMOTE'; ip_range = [PSCustomObject]@{ start = "10.0.0.$_"; end = $null } } }
            $connections = 1..35 | ForEach-Object {
                [PSCustomObject]@{ enabled = $true; direction_id = 0; protocol_ids = @(6); ports = @([PSCustomObject]@{ start = $_; end = $null; location = 'REMOTE' }) }
            }

            $fwPolicy1 = New-DummyFirewallPolicy -PolicyName 'Truncation Policy'
            $fwPolicy1.configuration.enforced_rules = @(
                (New-DummyFirewallRule -Name 'Lots Of Things Rule' -Action 'ALLOW' -Uid 'TRUNC001' -Connections $connections -Adapters $adapters -Applications $apps -Hosts $hosts)
            )

            $snapshot = New-DummyPolicySnapshot -FWPolicies @($fwPolicy1) -LocationMap $locMap

            Mock Get-SEPMPolicySnapshot -ModuleName PSSymantecSEPM { return $snapshot }

            $script:truncXlsxPath = Join-Path -Path 'TestDrive:' -ChildPath 'fw-trunc.xlsx'
            Export-SEPMFirewallPolicyToExcel -Path $script:truncXlsxPath
            $script:truncSheet = Import-Excel -Path $script:truncXlsxPath -WorksheetName 'FirewallRules'
        }

        It 'truncates Connections at 30 with count marker'  { $script:truncSheet[0].Connections  | Should -Match '\[5 more\]' }
        It 'truncates Adapters at 30 with count marker'     { $script:truncSheet[0].Adapters     | Should -Match '\[5 more\]' }
        It 'truncates Applications at 30 with count marker' { $script:truncSheet[0].Applications | Should -Match '\[5 more\]' }
        It 'truncates Hosts at 30 with count marker'        { $script:truncSheet[0].Hosts        | Should -Match '\[5 more\]' }
    }

    Context 'Pipeline mode' {
        BeforeAll {
            $locMap = @{ 'loc-001' = 'Default' }
            $fwPolicy1 = New-DummyFirewallPolicy -PolicyName 'FW Pipeline'
            $fwPolicy1.configuration.enforced_rules = @(
                (New-DummyFirewallRule -Name 'Allow DNS' -Action 'ALLOW' -Uid 'PIP001')
            )

            $script:pipelineSnapshot = New-DummyPolicySnapshot -FWPolicies @($fwPolicy1) -LocationMap $locMap

            Mock Get-SEPMPolicySnapshot -ModuleName PSSymantecSEPM {
                throw 'Get-SEPMPolicySnapshot should not be called in pipeline mode'
            }
        }

        It 'accepts SEPM.PolicySnapshot via pipeline and writes XLSX' {
            $xlsxPath = Join-Path -Path 'TestDrive:' -ChildPath 'fw-pipe.xlsx'
            $script:pipelineSnapshot | Export-SEPMFirewallPolicyToExcel -Path $xlsxPath
            $xlsxPath | Should -Exist
            $sheetNames = Get-ExcelSheetInfo -Path $xlsxPath | Select-Object -ExpandProperty Name
            $sheetNames | Should -Contain 'Policies'
            $sheetNames | Should -Contain 'FirewallRules'
            $sheetNames | Should -Contain 'PolicyAssignments'
        }

        It 'accepts snapshot by parameter' {
            $xlsxPath = Join-Path -Path 'TestDrive:' -ChildPath 'fw-param.xlsx'
            Export-SEPMFirewallPolicyToExcel -Path $xlsxPath -Snapshot $script:pipelineSnapshot
            $xlsxPath | Should -Exist
            (Get-ExcelSheetInfo -Path $xlsxPath).Name | Should -Contain 'Policies'
        }

        It 'accepts Deserialized.SEPM.PolicySnapshot via pipeline' {
            $xlsxPath = Join-Path -Path 'TestDrive:' -ChildPath 'fw-deser.xlsx'
            $xmlPath  = Join-Path -Path 'TestDrive:' -ChildPath 'snap.xml'
            $script:pipelineSnapshot | Export-Clixml -Path $xmlPath
            $deserialized = Import-Clixml -Path $xmlPath
            $deserialized | Export-SEPMFirewallPolicyToExcel -Path $xlsxPath
            $xlsxPath | Should -Exist
            $sheetNames = Get-ExcelSheetInfo -Path $xlsxPath | Select-Object -ExpandProperty Name
            $sheetNames | Should -Contain 'Policies'
            $sheetNames | Should -Contain 'FirewallRules'
            $sheetNames | Should -Contain 'PolicyAssignments'
        }
    }
}
