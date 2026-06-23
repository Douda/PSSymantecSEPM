[CmdletBinding()]
param()

Describe 'Export-SEPMInventory' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context 'Snapshot shape' {
        BeforeAll {
            $fakeSession = New-TestSession
            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }
            Mock Get-SEPMVersion -ModuleName PSSymantecSEPM {
                return @{ API_SEQUENCE = '230504014'; API_VERSION = '14.3.7000'; version = '14.3.9816.7000' }
            }
            Mock Get-SEPMDomain -ModuleName PSSymantecSEPM {
                return @{ id = 'abc123'; name = 'Default' }
            }
        }

        It 'returns snapshot with SEPM.Inventory PSTypeName' {
            $result = Export-SEPMInventory -OutputDir 'TestDrive:'
            $result.PSObject.TypeNames[0] | Should -Be 'SEPM.Inventory'
        }

        It 'FetchedAt is a [DateTime]' {
            $result = Export-SEPMInventory -OutputDir 'TestDrive:'
            $result.FetchedAt | Should -BeOfType [DateTime]
        }
    }

    Context 'Sub-cmdlet data gathering' {
        BeforeAll {
            $fakeSession = New-TestSession
            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }
            Mock Get-SEPMVersion -ModuleName PSSymantecSEPM {
                return @{ API_SEQUENCE = '230504014'; API_VERSION = '14.3.7000'; version = '14.3.9816.7000' }
            }
            Mock Get-SEPMDomain -ModuleName PSSymantecSEPM {
                return @{ id = 'abc123'; name = 'Default' }
            }
        }

        It 'stores Get-SEPMVersion output in Version property' {
            $result = Export-SEPMInventory -OutputDir 'TestDrive:'
            $result.Version.API_SEQUENCE | Should -Be '230504014'
            $result.Version.API_VERSION  | Should -Be '14.3.7000'
            $result.Version.version      | Should -Be '14.3.9816.7000'
        }

        It 'stores Get-SEPMDomain output in Domains property' {
            $result = Export-SEPMInventory -OutputDir 'TestDrive:'
            $result.Domains.id   | Should -Be 'abc123'
            $result.Domains.name | Should -Be 'Default'
        }
    }

    Context 'Per-category .clixml output' {
        BeforeAll {
            $fakeSession = New-TestSession
            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }
            Mock Get-SEPMVersion -ModuleName PSSymantecSEPM {
                return @{ API_SEQUENCE = '230504014'; API_VERSION = '14.3.7000'; version = '14.3.9816.7000' }
            }
            Mock Get-SEPMDomain -ModuleName PSSymantecSEPM {
                return @{ id = 'abc123'; name = 'Default' }
            }
        }

        It 'writes all_version.xml' {
            Export-SEPMInventory -OutputDir 'TestDrive:' | Out-Null
            Join-Path -Path 'TestDrive:' -ChildPath 'all_version.xml' | Should -Exist
        }

        It 'writes all_domains.xml' {
            Export-SEPMInventory -OutputDir 'TestDrive:' | Out-Null
            Join-Path -Path 'TestDrive:' -ChildPath 'all_domains.xml' | Should -Exist
        }

        It 'writes correct version data to all_version.xml' {
            Export-SEPMInventory -OutputDir 'TestDrive:' | Out-Null
            $imported = Import-Clixml -Path (Join-Path -Path 'TestDrive:' -ChildPath 'all_version.xml')
            $imported.API_SEQUENCE | Should -Be '230504014'
            $imported.version      | Should -Be '14.3.9816.7000'
        }

        It 'writes correct domain data to all_domains.xml' {
            Export-SEPMInventory -OutputDir 'TestDrive:' | Out-Null
            $imported = Import-Clixml -Path (Join-Path -Path 'TestDrive:' -ChildPath 'all_domains.xml')
            $imported.name | Should -Be 'Default'
        }
    }

    Context 'Timestamped snapshot blob' {
        BeforeAll {
            $fakeSession = New-TestSession
            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }
            Mock Get-SEPMVersion -ModuleName PSSymantecSEPM {
                return @{ API_SEQUENCE = '230504014'; API_VERSION = '14.3.7000'; version = '14.3.9816.7000' }
            }
            Mock Get-SEPMDomain -ModuleName PSSymantecSEPM {
                return @{ id = 'abc123'; name = 'Default' }
            }
        }

        It 'writes a timestamped .clixml blob' {
            Export-SEPMInventory -OutputDir 'TestDrive:' | Out-Null
            $blobs = Get-ChildItem -Path 'TestDrive:' -Filter 'SepmInventory_*.clixml'
            $blobs.Count | Should -BeGreaterThan 0
        }

        It 'blob content round-trips with SEPM.Inventory PSTypeName' {
            Export-SEPMInventory -OutputDir 'TestDrive:' | Out-Null
            $blobs = Get-ChildItem -Path 'TestDrive:' -Filter 'SepmInventory_*.clixml'
            $imported = Import-Clixml -Path $blobs[0].FullName
            $imported.PSObject.TypeNames[0] | Should -Be 'Deserialized.SEPM.Inventory'
            $imported.FetchedAt | Should -BeOfType [DateTime]
            $imported.Version.version | Should -Be '14.3.9816.7000'
        }

        It 'blob filename includes ISO 8601 timestamp' {
            Export-SEPMInventory -OutputDir 'TestDrive:' | Out-Null
            $blobs = Get-ChildItem -Path 'TestDrive:' -Filter 'SepmInventory_*.clixml'
            $blobs[0].Name | Should -Match '^SepmInventory_\d{4}-\d{2}-\d{2}T\d{2}-\d{2}-\d{2}\.clixml$'
        }
    }

    Context 'Failure capture' {
        BeforeAll {
            $fakeSession = New-TestSession
            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }
        }

        It 'captures version failure in Failures array' {
            Mock Get-SEPMVersion -ModuleName PSSymantecSEPM { throw 'Version API unavailable' }
            Mock Get-SEPMDomain -ModuleName PSSymantecSEPM {
                return @{ id = 'abc123'; name = 'Default' }
            }

            $result = Export-SEPMInventory -OutputDir 'TestDrive:'
            $result.Failures.Count | Should -Be 1
            $result.Failures[0].Category | Should -Be 'Version'
            $result.Failures[0].Error    | Should -Be 'Version API unavailable'
            $result.Version | Should -BeNullOrEmpty
            $result.Domains | Should -Not -BeNullOrEmpty
        }

        It 'captures domain failure in Failures array' {
            Mock Get-SEPMVersion -ModuleName PSSymantecSEPM {
                return @{ API_SEQUENCE = '230504014'; API_VERSION = '14.3.7000'; version = '14.3.9816.7000' }
            }
            Mock Get-SEPMDomain -ModuleName PSSymantecSEPM { throw 'Domain API unavailable' }

            $result = Export-SEPMInventory -OutputDir 'TestDrive:'
            $result.Failures.Count | Should -Be 1
            $result.Failures[0].Category | Should -Be 'Domains'
            $result.Failures[0].Error    | Should -Be 'Domain API unavailable'
            $result.Version | Should -Not -BeNullOrEmpty
            $result.Domains | Should -BeNullOrEmpty
        }

        It 'captures multiple failures' {
            Mock Get-SEPMVersion -ModuleName PSSymantecSEPM { throw 'Version API unavailable' }
            Mock Get-SEPMDomain -ModuleName PSSymantecSEPM { throw 'Domain API unavailable' }

            $result = Export-SEPMInventory -OutputDir 'TestDrive:'
            $result.Failures.Count | Should -Be 2
            $result.Failures[0].Category | Should -Be 'Version'
            $result.Failures[1].Category | Should -Be 'Domains'
        }

        It 'writes _failed.xml when a category fails' {
            Mock Get-SEPMVersion -ModuleName PSSymantecSEPM { throw 'Version API unavailable' }
            Mock Get-SEPMDomain -ModuleName PSSymantecSEPM {
                return @{ id = 'abc123'; name = 'Default' }
            }

            # Clean any leftover _failed.xml from prior tests in this Context
            Get-ChildItem -Path 'TestDrive:' -Filter '*_failed.xml' | Remove-Item -Force -ErrorAction SilentlyContinue

            Export-SEPMInventory -OutputDir 'TestDrive:' | Out-Null
            Join-Path -Path 'TestDrive:' -ChildPath 'Version_failed.xml' | Should -Exist
            Join-Path -Path 'TestDrive:' -ChildPath 'Domains_failed.xml' | Should -Not -Exist
        }
    }

    Context 'OutputDir parameter' {
        BeforeAll {
            $fakeSession = New-TestSession
            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }
            Mock Get-SEPMVersion -ModuleName PSSymantecSEPM {
                return @{ API_SEQUENCE = '230504014'; API_VERSION = '14.3.7000'; version = '14.3.9816.7000' }
            }
            Mock Get-SEPMDomain -ModuleName PSSymantecSEPM {
                return @{ id = 'abc123'; name = 'Default' }
            }
        }

        It 'writes files to the specified OutputDir' {
            $customDir = Join-Path -Path 'TestDrive:' -ChildPath 'custom_inventory'
            New-Item -Path $customDir -ItemType Directory -Force | Out-Null
            Export-SEPMInventory -OutputDir $customDir | Out-Null

            Join-Path -Path $customDir -ChildPath 'all_version.xml' | Should -Exist
            Join-Path -Path $customDir -ChildPath 'all_domains.xml' | Should -Exist
        }
    }

    Context 'DelayMs parameter' {
        BeforeAll {
            $fakeSession = New-TestSession
            Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }
            Mock Get-SEPMVersion -ModuleName PSSymantecSEPM {
                return @{ API_SEQUENCE = '230504014'; API_VERSION = '14.3.7000'; version = '14.3.9816.7000' }
            }
            Mock Get-SEPMDomain -ModuleName PSSymantecSEPM {
                return @{ id = 'abc123'; name = 'Default' }
            }
        }

        It 'calls Get-SEPMVersion then Get-SEPMDomain with delay' {
            $script:callOrder = @()
            Mock Get-SEPMVersion -ModuleName PSSymantecSEPM {
                $script:callOrder += 'Version'
                return @{ API_SEQUENCE = '230504014'; API_VERSION = '14.3.7000'; version = '14.3.9816.7000' }
            }
            Mock Get-SEPMDomain -ModuleName PSSymantecSEPM {
                $script:callOrder += 'Domains'
                return @{ id = 'abc123'; name = 'Default' }
            }

            Export-SEPMInventory -OutputDir 'TestDrive:' -DelayMs 1 | Out-Null
            $script:callOrder[0] | Should -Be 'Version'
            $script:callOrder[1] | Should -Be 'Domains'
        }
    }
}
