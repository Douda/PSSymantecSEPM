[CmdletBinding()]
param()

Describe 'Get-SEPMHostGroup' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context 'ById' {
        It 'returns full Host Group detail (name + hosts) when given an ID' {
            $null = Set-TestMocks -SkipCert -Transport {
                return @{
                    name  = 'WebServers'
                    hosts = @(
                        @{ hostValue = '10.0.0.1'; hostType = 'IP_RANGE'; description = '' }
                        @{ hostValue = '192.168.1.0/24'; hostType = 'SUBNET'; description = '' }
                    )
                }
            }

            $result = Get-SEPMHostGroup -Id 'hg1'
            $result | Should -Not -BeNullOrEmpty
            $result.name  | Should -Be 'WebServers'
            @($result.hosts).Count | Should -Be 2
        }

        It 'accepts ID from pipeline via property name' {
            $null = Set-TestMocks -SkipCert -Transport {
                param($Uri)
                if ($Uri -match '/hostgroups/hg2') {
                    return @{
                        name  = 'DatabaseServers'
                        hosts = @()
                    }
                }
                return @{ name = 'WebServers'; hosts = @() }
            }

            $inputObj = [PSCustomObject]@{ id = 'hg2'; name = 'DatabaseServers' }
            $result = $inputObj | Get-SEPMHostGroup
            $result.name | Should -Be 'DatabaseServers'
        }
    }

    Context 'ByName' {
        It 'resolves by exact name and returns full detail' {
            $null = Set-TestMocks -SkipCert -Transport {
                param($Uri)
                if ($Uri -match '/hostgroups/summary') {
                    return @{
                        content   = @(
                            @{ id = 'hg1'; name = 'WebServers'; domainid = 'dom1'; lastmodifiedtime = 1693832218775 }
                        )
                        firstPage = $true
                        lastPage  = $true
                    }
                }
                if ($Uri -match '/hostgroups/hg1') {
                    return @{
                        name  = 'WebServers'
                        hosts = @(
                            @{ hostValue = '10.0.0.1'; hostType = 'IP_RANGE'; description = '' }
                        )
                    }
                }
                return $null
            }

            $result = Get-SEPMHostGroup -Name 'WebServers'
            $result | Should -Not -BeNullOrEmpty
            $result.name | Should -Be 'WebServers'
            @($result.hosts).Count | Should -Be 1
        }

        It 'resolves by wildcard name and returns all matches' {
            $detailCalls = @()
            $null = Set-TestMocks -SkipCert -Transport {
                param($Uri)
                if ($Uri -match '/hostgroups/summary') {
                    return @{
                        content   = @(
                            @{ id = 'dmz1'; name = 'DMZ-Web'; domainid = 'dom1'; lastmodifiedtime = 1693832218775 }
                            @{ id = 'dmz2'; name = 'DMZ-App'; domainid = 'dom1'; lastmodifiedtime = 1693832218776 }
                        )
                        firstPage = $true
                        lastPage  = $true
                    }
                }
                if ($Uri -match '/hostgroups/dmz') {
                    $detailCalls += $Uri
                    return @{
                        name  = if ($Uri -match 'dmz1') { 'DMZ-Web' } else { 'DMZ-App' }
                        hosts = @()
                    }
                }
                return $null
            }

            $result = Get-SEPMHostGroup -Name 'DMZ-*'
            @($result).Count | Should -Be 2
            $result[0].name | Should -Be 'DMZ-Web'
            $result[1].name | Should -Be 'DMZ-App'
        }

        It 'returns empty array when no name matches' {
            $null = Set-TestMocks -SkipCert -Transport {
                param($Uri)
                if ($Uri -match '/hostgroups/summary') {
                    return @{
                        content   = @(
                            @{ id = 'hg1'; name = 'WebServers'; domainid = 'dom1'; lastmodifiedtime = 1693832218775 }
                        )
                        firstPage = $true
                        lastPage  = $true
                    }
                }
                return $null
            }

            $result = Get-SEPMHostGroup -Name 'NonExistent'
            @($result).Count | Should -Be 0
        }
    }

    Context 'Parameter sets' {
        It '-Id and -Name are mutually exclusive' {
            { Get-SEPMHostGroup -Id 'hg1' -Name 'WebServers' -ErrorAction Stop } |
                Should -Throw -ErrorId 'AmbiguousParameterSet,Get-SEPMHostGroup'
        }
    }
}
