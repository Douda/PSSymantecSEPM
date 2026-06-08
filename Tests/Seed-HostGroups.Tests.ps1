[CmdletBinding()]
param()

Describe 'HostGroups seed data file' {
    BeforeAll {
        $script:SeedDir = Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath 'Source/Seed'
        $script:HostGroupsFile = Join-Path -Path $script:SeedDir -ChildPath 'HostGroups.psd1'
        $script:Data = Import-PowerShellDataFile -Path $script:HostGroupsFile -ErrorAction Stop
    }

    Context 'File structure' {
        It 'imports without errors via Import-PowerShellDataFile' {
            $script:Data | Should -Not -BeNullOrEmpty
        }

        It 'contains a HostGroups key' {
            $script:Data.ContainsKey('HostGroups') | Should -BeTrue
            $script:Data.HostGroups | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Entry count' {
        It 'has 2 host group entries' {
            $script:Data.HostGroups.Count | Should -Be 2
        }
    }

    Context 'Specific entries' {
        It 'Corporate LAN exists with correct name' {
            $hg = $script:Data.HostGroups | Where-Object { $_.Name -eq 'Corporate LAN' }
            $hg | Should -Not -BeNullOrEmpty
        }

        It 'Corporate LAN has 3 hosts' {
            $hg = $script:Data.HostGroups | Where-Object { $_.Name -eq 'Corporate LAN' }
            $hg.Hosts.Count | Should -Be 3
        }

        It 'Corporate LAN host types are correct' {
            $hg = $script:Data.HostGroups | Where-Object { $_.Name -eq 'Corporate LAN' }
            $hg.Hosts[0].ContainsKey('ipv4_subnet') | Should -BeTrue
            $hg.Hosts[1].ContainsKey('ipv4_subnet') | Should -BeTrue
            $hg.Hosts[2].ContainsKey('ip') | Should -BeTrue
        }

        It 'DMZ Servers exists with correct name' {
            $hg = $script:Data.HostGroups | Where-Object { $_.Name -eq 'DMZ Servers' }
            $hg | Should -Not -BeNullOrEmpty
        }

        It 'DMZ Servers has 2 hosts' {
            $hg = $script:Data.HostGroups | Where-Object { $_.Name -eq 'DMZ Servers' }
            $hg.Hosts.Count | Should -Be 2
        }

        It 'DMZ Servers host types are correct' {
            $hg = $script:Data.HostGroups | Where-Object { $_.Name -eq 'DMZ Servers' }
            $hg.Hosts[0].ContainsKey('ipv4_subnet') | Should -BeTrue
            $hg.Hosts[1].ContainsKey('ip') | Should -BeTrue
        }
    }

    Context 'Host format' {
        It 'ipv4_subnet hosts have ip and mask keys' {
            foreach ($hg in $script:Data.HostGroups) {
                foreach ($hostEntry in $hg.Hosts) {
                    if ($hostEntry.ContainsKey('ipv4_subnet')) {
                        $hostEntry.ipv4_subnet.ContainsKey('ip') | Should -BeTrue -Because "'$($hg.Name)' subnet must have ip"
                        $hostEntry.ipv4_subnet.ContainsKey('mask') | Should -BeTrue -Because "'$($hg.Name)' subnet must have mask"
                        $hostEntry.ipv4_subnet.ip | Should -Not -BeNullOrEmpty
                        $hostEntry.ipv4_subnet.mask | Should -Not -BeNullOrEmpty
                    }
                }
            }
        }

        It 'ip hosts have valid IP strings' {
            foreach ($hg in $script:Data.HostGroups) {
                foreach ($hostEntry in $hg.Hosts) {
                    if ($hostEntry.ContainsKey('ip')) {
                        $hostEntry.ip | Should -Not -BeNullOrEmpty
                        $hostEntry.ip | Should -Match '^\d+\.\d+\.\d+\.\d+$'
                    }
                }
            }
        }

        It 'each host has exactly one type key' {
            $validKeys = @('ip', 'ipv4_subnet', 'ipv4_range', 'mac', 'dns_domain', 'dns_host', 'ipv6_subnet', 'ipv6_range')
            foreach ($hg in $script:Data.HostGroups) {
                foreach ($hostEntry in $hg.Hosts) {
                    $typeKeys = @($hostEntry.Keys | Where-Object { $_ -in $validKeys })
                    $typeKeys.Count | Should -Be 1 -Because "'$($hg.Name)' host must have exactly one type key, got: $($typeKeys -join ', ')"
                }
            }
        }
    }

    Context 'No hardcoded IDs' {
        It 'no entry has hardcoded IDs' {
            $text = Get-Content -Path $script:HostGroupsFile -Raw
            $text -match '\bid\s*=' | Should -BeFalse -Because 'entries must not have hardcoded IDs'
        }
    }

    Context 'File encoding' {
        It 'has no BOM (PS7-compatible)' {
            $bytes = [System.IO.File]::ReadAllBytes($script:HostGroupsFile)
            $hasBOM = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
            $hasBOM | Should -BeFalse -Because 'PS7 .psd1 files must not have UTF-8 BOM'
        }

        It 'starts with @{ (valid .psd1 syntax)' {
            $firstLine = Get-Content -Path $script:HostGroupsFile -First 1
            $firstLine.TrimStart() | Should -Match '^@\{'
        }
    }
}
