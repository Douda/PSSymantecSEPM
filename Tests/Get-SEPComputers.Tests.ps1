[CmdletBinding()]
param()

# Build & Load the module
$moduleRootPath = Split-Path -Path $PSScriptRoot -Parent
. (Join-Path -Path $moduleRootPath -ChildPath 'Tests\Config\Common-Init.ps1')



Describe 'Get-SEPComputers' {
    InModuleScope PSSymantecSEPM { 
        BeforeAll {
            # This is common test code setup logic for all Pester test files
            $moduleRootPath = Split-Path -Path $PSScriptRoot -Parent
            . (Join-Path -Path $moduleRootPath -ChildPath 'Tests\Config\Common-BeforeAll.ps1')

            # Load Pester test environment setup
            . (Join-Path -Path $moduleRootPath -ChildPath 'Tests\Config\Common-TestEnvironmentSetup.ps1')

            function New-DummyDataSEPComputers {
                <#
            .SYNOPSIS
                Generates a dummy SEP Computer object for testing purposes.
            .DESCRIPTION
                Generates a dummy SEP Computer object for testing purposes.
                They're supposed to look similar to the ones returned by the Get-SEPComputers cmdlet.
            .PARAMETER ComputerName
                Generates a dummy SEP Computer object with the specified computer name.
            .EXAMPLE
                1..3 | New-DummyDataSEPComputers

                group             : @{id=7c4d2d27-d7e0-43ef-8c75-008383312b62; name=My Company\\test group 88;
                                    fullPathName=; externalReferenceId=; source=; domain=}
                ipAddresses       : {112.157.108.212, B126:712F:8D34:4788:EBC0:E515:CBFD:B31F}
                macAddresses      : {45-65-5A-0A-78-58, 45-65-5A-0A-78-58}
                gateways          : {25.93.38.195, 49.27.148.201, 161.106.231.189, 21.186.123.6}
                subnetMasks       : {79.71.18.0, 64}
                dnsServers        : {15.54.206.121, 1F5B:9FFA:C68D:8B99:0ED2:1993:6285:CF63}
                winServers        : {246.94.104.55, 246.94.104.55}
                description       : Description of computer id: 7c4d2d27-d7e0-43ef-8c75-008383312b62
                computerName      : WIN-7653
                lastInventoryDate : 28/02/2024 17:18:47
                lastModifiedDate  : 28/02/2024 17:18:47
                createdDate       : 28/02/2024 17:18:47
                createdBy         : User36
                lastModifiedBy    : User67
                version           : 8
                deleted           : False

                Generates 3 dummy SEP Computer objects for testing purposes.
            #>
                [CmdletBinding()]
                param (
                    # ComputerName
                    [Parameter()]
                    [String]
                    $ComputerName,

                    # GroupName
                    [Parameter()]
                    [String]
                    $GroupName
                )
    
                process {
                    $customObject = New-Object PSObject
                    # ComputerName
                    if ($ComputerName) {
                        $customObject | Add-Member -Type NoteProperty -Name "computerName" -Value $ComputerName
                    } else {
                        $customObject | Add-Member -Type NoteProperty -Name "computerName" -Value ("WIN-" + (Get-Random -Minimum 1 -Maximum 10000))
                    }
                    $group = New-Object PSObject
                    # GroupName
                    if ($GroupName) {
                        $group | Add-Member -Type NoteProperty -Name "name" -Value $GroupName
                    } else {
                        $group | Add-Member -Type NoteProperty -Name "name" -Value ("My Company\\test group " + (Get-Random -Minimum 1 -Maximum 100))
                    }
                    $group | Add-Member -Type NoteProperty -Name "id" -Value ([guid]::NewGuid().ToString())
                    $group | Add-Member -Type NoteProperty -Name "fullPathName" -Value $null
                    $group | Add-Member -Type NoteProperty -Name "externalReferenceId" -Value $null
                    $group | Add-Member -Type NoteProperty -Name "source" -Value $null

                    # Domain from the group
                    $domain = New-Object PSObject
                    $domain | Add-Member -Type NoteProperty -Name "id" -Value ([guid]::NewGuid().ToString())
                    $domain | Add-Member -Type NoteProperty -Name "name" -Value "Default"
                    $group | Add-Member -Type NoteProperty -Name "domain" -Value $domain
                    $customObject | Add-Member -Type NoteProperty -Name "group" -Value $group

                    # IpAddresses
                    $ipv4 = ((1..4 | ForEach-Object { Get-Random -Minimum 1 -Maximum 255 }) -join '.')
                    $ipv6 = ((1..8 | ForEach-Object { "{0:X4}" -f (Get-Random -Minimum 0x0000 -Maximum 0xFFFF) }) -join ':')
                    $customObject | Add-Member -Type NoteProperty -Name "ipAddresses" -Value @($ipv4, $ipv6)

                    # MacAddresses
                    $mac = ((1..6 | ForEach-Object { "{0:X2}" -f (Get-Random -Minimum 0 -Maximum 256) }) -join '-')
                    $customObject | Add-Member -Type NoteProperty -Name "macAddresses" -Value @(1..2 | ForEach-Object { $mac })

                    # Gateways
                    $gateways = @(1..4 | ForEach-Object { ((1..4 | ForEach-Object { Get-Random -Minimum 1 -Maximum 255 }) -join '.') })
                    $customObject | Add-Member -Type NoteProperty -Name "gateways" -Value $gateways

                    # SubnetMasks
                    $subnetMasks = @((ForEach-Object { (1..3 | ForEach-Object { Get-Random -Minimum 1 -Maximum 255 }) -join '.' }) + ".0")
                    $customObject | Add-Member -Type NoteProperty -Name "subnetMasks" -Value @($subnetMasks, "64")

                    # DnsServers
                    $dnsv4 = ((1..4 | ForEach-Object { Get-Random -Minimum 1 -Maximum 255 }) -join '.')
                    $dnsv6 = ((1..8 | ForEach-Object { "{0:X4}" -f (Get-Random -Minimum 0x0000 -Maximum 0xFFFF) }) -join ':')
                    $customObject | Add-Member -Type NoteProperty -Name "dnsServers" -Value @($dnsv4, $dnsv6)

                    # WinServers
                    $Wins = ((1..4 | ForEach-Object { Get-Random -Minimum 1 -Maximum 255 }) -join '.')
                    $customObject | Add-Member -Type NoteProperty -Name "winServers" -Value @(1..2 | ForEach-Object { $Wins })

                    $customObject | Add-Member -Type NoteProperty -Name "description" -Value ("Description of computer id: " + $group.id)
                    $customObject | Add-Member -Type NoteProperty -Name "lastInventoryDate" -Value (Get-Date)
                    $customObject | Add-Member -Type NoteProperty -Name "lastModifiedDate" -Value (Get-Date)
                    $customObject | Add-Member -Type NoteProperty -Name "createdDate" -Value (Get-Date)
                    $customObject | Add-Member -Type NoteProperty -Name "createdBy" -Value ("User" + (Get-Random -Minimum 1 -Maximum 100))
                    $customObject | Add-Member -Type NoteProperty -Name "lastModifiedBy" -Value ("User" + (Get-Random -Minimum 1 -Maximum 100))
                    $customObject | Add-Member -Type NoteProperty -Name "version" -Value (Get-Random -Minimum 1 -Maximum 10)
                    $customObject | Add-Member -Type NoteProperty -Name "deleted" -Value $false

                    # $customObject.PSTypeNames.Insert(0, "SEP.Computer")
                    return $customObject
                }
            }

            # Mock Test-SEPMAccessToken to return true for valid token
            Mock Test-SEPMAccessToken -ModuleName $script:moduleName { return $true }

            # API Call - 1st page always contains 100 computers
            $script:APIResponseFirstPage = [PSCustomObject]@{
                content   = (1..100 | ForEach-Object { New-DummyDataSEPComputers })
                firstPage = $true
                lastPage  = $false
            }

            # API Call - Last page always contains 5 computers
            $script:APIResponseLastPage = [PSCustomObject]@{
                content   = (1..5 | ForEach-Object { New-DummyDataSEPComputers })
                firstPage = $false
                lastPage  = $true
            }

            # Mock Invoke-ABRestMethod to return a valid response with only one page
            Mock Invoke-ABRestMethod -ModuleName $script:moduleName -ParameterFilter {
                $params.Uri -eq $URI -and $params.Method -eq 'GET'
            } { 
                return $script:APIResponseLastPage
            }
        }

        AfterAll {
            # This is common test code teardown logic for all Pester test files
            $moduleRootPath = Split-Path -Path $PSScriptRoot -Parent
            . (Join-Path -Path $moduleRootPath -ChildPath 'Tests\Config\Common-AfterAll.ps1')
        }

        Context 'No parameters' {
            BeforeAll {}
            Context 'Without pagination' {
                BeforeAll {
                    # Mock Invoke-ABRestMethod to return a valid response with only one page / 5 computers
                    Mock Invoke-ABRestMethod -ModuleName $script:moduleName -ParameterFilter {
                        $params.Uri -eq $URI -and $params.Method -eq 'GET'
                    } { 
                        return $script:APIResponseLastPage
                    }
                }
                It 'Should return exactly one page of computers' {
                    $result = Get-SEPComputers
                    $result | Should -Not -BeNullOrEmpty
                    $result.count | Should -Be 5
                    # Only one API call
                    Should -Invoke Invoke-ABRestMethod -Exactly 1 -Scope It
                }

                It 'Should have the expected type' {
                    $result = Get-SEPComputers
                    $result[0].PSObject.TypeNames[0] | Should -Be 'SEP.Computer'
                }
            }

            Context 'With pagination' {
                BeforeAll {
                    # Mock Invoke-ABRestMethod to return a valid response with multiple pages
                    $script:callCount = 0
                    Mock Invoke-ABRestMethod -ModuleName $script:moduleName -ParameterFilter {
                        $params.Uri -eq $URI -and $params.Method -eq 'GET'
                    } { 
                        $script:callCount++
                        if ($script:callCount -ge 2) {
                            return $script:APIResponseLastPage
                        } else {
                            return $script:APIResponseFirstPage
                        }
                    }
                }

                It 'Should perform exactly 2 API calls to get all computers' {
                    $result = Get-SEPComputers
                    $result | Should -Not -BeNullOrEmpty
                    # Exactly two API calls
                    Should -Invoke Invoke-ABRestMethod -Exactly 2 -Scope It
                }

                It 'Should have the expected type' {
                    $result = Get-SEPComputers
                    $result[0].PSObject.TypeNames[0] | Should -Be 'SEP.Computer'
                }
            }
        }

        Context 'ComputerName parameter' {
            BeforeAll {
                # Mock Invoke-ABRestMethod to return a valid response with only one computer called "MyComputer"
                Mock Invoke-ABRestMethod -ModuleName $script:moduleName -ParameterFilter {
                    $params.Uri -eq $URI -and $params.Method -eq 'GET'
                } { 
                    return [PSCustomObject]@{
                        content   = (New-DummyDataSEPComputers -ComputerName "MyComputer")
                        firstPage = $true
                        lastPage  = $true
                    }
                }
            }
            It 'Should contain MyComputer only' {
                $result = Get-SEPComputers -ComputerName "MyComputer"
                $result | Should -Not -BeNullOrEmpty
                $result.computername | Should -Be "MyComputer"
            }

            It 'With Computername from the pipeline' {
                $result = "MyComputer" | Get-SEPComputers
                $result | Should -Not -BeNullOrEmpty
                $result.computername | Should -Be "MyComputer"
            }

            It 'Should have the expected type' {
                $result = Get-SEPComputers -ComputerName "MyComputer"
                $result.PSObject.TypeNames[0] | Should -Be 'SEP.Computer'
            }
        }

        Context 'GroupName parameter' {
            BeforeAll {
                # Mock Invoke-ABRestMethod to return a valid response
                # 2 pages / 105 computers / only 5 from the group "My Company\\MyGroup"
                $script:callCount = 0
                Mock Invoke-ABRestMethod -ModuleName $script:moduleName -ParameterFilter {
                    $params.Uri -eq $URI -and $params.Method -eq 'GET'
                } { 
                    $script:callCount++
                    if ($script:callCount -ge 2) {
                        return [PSCustomObject]@{
                            content   = (1..5 | ForEach-Object { New-DummyDataSEPComputers -GroupName "My Company\\MyGroup" })
                            firstPage = $false
                            lastPage  = $true
                        }
                    } else {
                        return [PSCustomObject]@{
                            content   = (1..100 | ForEach-Object { New-DummyDataSEPComputers })
                            firstPage = $true
                            lastPage  = $false
                        }
                    }
                }
            }
            It 'Should contain only computers from the group "My Company\\MyGroup"' {
                $result = Get-SEPComputers -GroupName "My Company\\MyGroup"
                $result | Should -Not -BeNullOrEmpty
                $result | Should -HaveCount 5
            }

            It 'Should have the expected type' {
                $result = Get-SEPComputers -GroupName "My Company\\MyGroup"
                $result[0].PSObject.TypeNames[0] | Should -Be 'SEP.Computer'
            }
        }
    }
}

