[CmdletBinding()]
param()

Describe 'Groups seed data file' {
    BeforeAll {
        $script:SeedDir = Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath 'Source/Seed'
        $script:GroupsFile = Join-Path -Path $script:SeedDir -ChildPath 'Groups.psd1'
        $script:Data = Import-PowerShellDataFile -Path $script:GroupsFile -ErrorAction Stop

        # Recursive tree-walker: returns flattened list of all nodes with their depth
        function Get-GroupNodes {
            param($Nodes, [int]$Depth = 0)
            foreach ($node in $Nodes) {
                if ($node -is [string]) {
                    # Leaf subgroup name — skip (no Name/Description to validate)
                    continue
                }
                $children = if ($node.ContainsKey('Children') -and $node.Children) { $node.Children } else { @() }
                [PSCustomObject]@{
                    Name        = $node.Name
                    Description = $node.Description
                    Depth       = $Depth
                    IsLeaf      = ($children.Count -eq 0)
                    HasChildren = ($children.Count -gt 0)
                    Children    = $children
                }
                if ($children.Count -gt 0) {
                    Get-GroupNodes -Nodes $children -Depth ($Depth + 1)
                }
            }
        }
    }

    Context 'File structure' {
        It 'imports without errors via Import-PowerShellDataFile' {
            $script:Data | Should -Not -BeNullOrEmpty
        }

        It 'contains a Groups key' {
            $script:Data.ContainsKey('Groups') | Should -BeTrue
            $script:Data.Groups | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Top-level structure' {
        It 'has 3 regions: EMEA, NA, APJ' {
            $script:Data.Groups.Count | Should -Be 3
            $script:Data.Groups.Name | Should -Contain 'EMEA'
            $script:Data.Groups.Name | Should -Contain 'NA'
            $script:Data.Groups.Name | Should -Contain 'APJ'
        }

        It 'regions have correct Description formula' {
            foreach ($region in $script:Data.Groups) {
                $region.Description | Should -BeExactly "Region - $($region.Name)"
            }
        }
    }

    Context 'Country level' {
        BeforeAll {
            $script:Countries = $script:Data.Groups | ForEach-Object { ,$_.Children }
        }

        It 'each region has 5 countries' {
            foreach ($countryList in $script:Countries) {
                $countryList.Count | Should -Be 5
            }
        }

        It 'EMEA countries: UK, Germany, France, Spain, Italy' {
            $emea = ($script:Data.Groups | Where-Object { $_.Name -eq 'EMEA' }).Children
            $emea.Name | Should -Contain 'UK'
            $emea.Name | Should -Contain 'Germany'
            $emea.Name | Should -Contain 'France'
            $emea.Name | Should -Contain 'Spain'
            $emea.Name | Should -Contain 'Italy'
        }

        It 'NA countries: US, Canada, Mexico, Brazil, Argentina' {
            $na = ($script:Data.Groups | Where-Object { $_.Name -eq 'NA' }).Children
            $na.Name | Should -Contain 'US'
            $na.Name | Should -Contain 'Canada'
            $na.Name | Should -Contain 'Mexico'
            $na.Name | Should -Contain 'Brazil'
            $na.Name | Should -Contain 'Argentina'
        }

        It 'APJ countries: Japan, Australia, India, China, Singapore' {
            $apj = ($script:Data.Groups | Where-Object { $_.Name -eq 'APJ' }).Children
            $apj.Name | Should -Contain 'Japan'
            $apj.Name | Should -Contain 'Australia'
            $apj.Name | Should -Contain 'India'
            $apj.Name | Should -Contain 'China'
            $apj.Name | Should -Contain 'Singapore'
        }

        It 'countries have correct Description formula' {
            $allCountries = $script:Data.Groups | ForEach-Object { $_.Children } | ForEach-Object { $_ }
            foreach ($country in $allCountries) {
                $country.Description | Should -BeExactly "Country - $($country.Name)"
            }
        }
    }

    Context 'Every node has Name and Description' {
        It 'all nodes have Name and Description fields' {
            $nodes = Get-GroupNodes -Nodes $script:Data.Groups
            foreach ($node in $nodes) {
                $node.Name | Should -Not -BeNullOrEmpty
                $node.Description | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context 'City level' {
        BeforeAll {
            # All city lists (one per country) — prevent unrolling with unary comma
            $script:CityLists = $script:Data.Groups | ForEach-Object { $_.Children } | ForEach-Object { ,$_.Children }
            # All city nodes flattened
            $script:AllCities = $script:CityLists | ForEach-Object { $_ }
        }

        It 'each country has 2 cities' {
            foreach ($cityList in $script:CityLists) {
                $cityList.Count | Should -Be 2
            }
        }

        It 'EMEA cities are correct' {
            $emeaCountries = ($script:Data.Groups | Where-Object { $_.Name -eq 'EMEA' }).Children
            $cities = @{
                UK      = @('London', 'Manchester')
                Germany = @('Berlin', 'Munich')
                France  = @('Paris', 'Lyon')
                Spain   = @('Madrid', 'Barcelona')
                Italy   = @('Rome', 'Milan')
            }
            foreach ($country in $emeaCountries) {
                $expected = $cities[$country.Name]
                $country.Children.Name | Should -Be $expected
            }
        }

        It 'NA cities are correct' {
            $naCountries = ($script:Data.Groups | Where-Object { $_.Name -eq 'NA' }).Children
            $cities = @{
                US        = @('New York', 'San Francisco')
                Canada    = @('Toronto', 'Vancouver')
                Mexico    = @('Mexico City', 'Monterrey')
                Brazil    = @('Sao Paulo', 'Rio de Janeiro')
                Argentina = @('Buenos Aires', 'Cordoba')
            }
            foreach ($country in $naCountries) {
                $expected = $cities[$country.Name]
                $country.Children.Name | Should -Be $expected
            }
        }

        It 'APJ cities are correct' {
            $apjCountries = ($script:Data.Groups | Where-Object { $_.Name -eq 'APJ' }).Children
            $cities = @{
                Japan     = @('Tokyo', 'Osaka')
                Australia = @('Sydney', 'Melbourne')
                India     = @('Mumbai', 'Bangalore')
                China     = @('Beijing', 'Shanghai')
                Singapore = @('Singapore Central', 'Singapore East')
            }
            foreach ($country in $apjCountries) {
                $expected = $cities[$country.Name]
                $country.Children.Name | Should -Be $expected
            }
        }

        It 'cities have correct Description formula' {
            foreach ($city in $script:AllCities) {
                $city.Description | Should -BeExactly "City - $($city.Name)"
            }
        }
    }

    Context 'Base leaves (per city)' {
        It 'every city has Servers and Workstations leaves' {
            foreach ($city in $script:AllCities) {
                $city.Children.Count | Should -Be 2 -Because "city '$($city.Name)' should have exactly 2 base leaves"
                $leafNames = $city.Children.Name
                $leafNames | Should -Contain 'Servers'
                $leafNames | Should -Contain 'Workstations'
            }
        }

        It 'Servers is always a leaf (no Children)' {
            foreach ($city in $script:AllCities) {
                $servers = $city.Children | Where-Object { $_.Name -eq 'Servers' }
                if ($servers -is [array]) { $servers = $servers[0] }
                $servers | Should -Not -BeNullOrEmpty
                (-not $servers.ContainsKey('Children') -or $servers.Children.Count -eq 0) |
                    Should -BeTrue -Because "Servers in '$($city.Name)' should have no children"
            }
        }
    }

    Context 'Workstation subgroups' {
        BeforeAll {
            # Map of city name -> expected subgroup names (or $null for no subgroups)
            $script:WorkstationSubgroups = @{
                London             = @('HR Exception Machines')
                'New York'         = @('HR Exception Machines')
                Tokyo              = @('HR Exception Machines')
                Manchester         = @('Small Office')
                Toronto            = @('Small Office')
                Sydney             = @('Small Office')
                Berlin             = @('Entrance Office')
                'San Francisco'    = @('Entrance Office')
                Mumbai             = @('Entrance Office')
                Paris              = @('Developers')
                Vancouver          = @('Developers')
                Barcelona          = @('Developers')
                Shanghai           = @('Developers')
                Rome               = @('Executives')
                Lyon               = @('Executives')
                'Buenos Aires'     = @('Executives')
                'Sao Paulo'        = @('Executives')
                'Singapore Central' = @('Executives')
            }
        }

        It 'selected cities have correct Workstation subgroups' {
            foreach ($city in $script:AllCities) {
                $ws = $city.Children | Where-Object { $_.Name -eq 'Workstations' }
                if ($ws -is [array]) { $ws = $ws[0] }

                $expectedSubgroups = $script:WorkstationSubgroups[$city.Name]
                $hasChildren = $ws.ContainsKey('Children') -and $ws.Children.Count -gt 0

                if ($expectedSubgroups) {
                    $hasChildren | Should -BeTrue -Because "Workstations in '$($city.Name)' should have subgroups"
                    $actualNames = $ws.Children | ForEach-Object {
                        if ($_ -is [string]) { $_ } else { $_.Name }
                    }
                    foreach ($sub in $expectedSubgroups) {
                        $actualNames | Should -Contain $sub -Because "'$($city.Name)' should have subgroup '$sub'"
                    }
                }
            }
        }

        It 'cities without subgroups have Workstations as plain leaf' {
            foreach ($city in $script:AllCities) {
                if ($script:WorkstationSubgroups.ContainsKey($city.Name)) { continue }

                $ws = $city.Children | Where-Object { $_.Name -eq 'Workstations' }
                if ($ws -is [array]) { $ws = $ws[0] }

                $ws | Should -Not -BeNullOrEmpty -Because "'$($city.Name)' should have Workstations"
                (-not $ws.ContainsKey('Children') -or $ws.Children.Count -eq 0) |
                    Should -BeTrue -Because "Workstations in '$($city.Name)' should have no children"
            }
        }
    }

    Context 'Total group count' {
        It 'has 108 groups (3 regions + 15 countries + 30 cities + 60 leaves)' {
            $nodes = Get-GroupNodes -Nodes $script:Data.Groups
            $nodes.Count | Should -Be 108
        }
    }

    Context 'File encoding' {
        It 'has no BOM (PS7-compatible)' {
            $bytes = [System.IO.File]::ReadAllBytes($script:GroupsFile)
            $hasBOM = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
            $hasBOM | Should -BeFalse -Because 'PS7 .psd1 files must not have UTF-8 BOM'
        }

        It 'starts with @{ (valid .psd1 syntax)' {
            $firstLine = Get-Content -Path $script:GroupsFile -First 1
            $firstLine.TrimStart() | Should -Match '^@\{'
        }
    }

    Context 'Leaf format' {
        It 'Workstation subgroup leaves are strings' {
            foreach ($city in $script:AllCities) {
                if (-not $script:WorkstationSubgroups.ContainsKey($city.Name)) { continue }
                $ws = $city.Children | Where-Object { $_.Name -eq 'Workstations' }
                if ($ws -is [array]) { $ws = $ws[0] }
                if ($ws.Children) {
                    foreach ($child in $ws.Children) {
                        $child -is [string] | Should -BeTrue -Because "subgroup in '$($city.Name)' should be a string"
                    }
                }
            }
        }

        It 'no node has hardcoded IDs' {
            $text = Get-Content -Path $script:GroupsFile -Raw
            $text -match '\bid\s*=' | Should -BeFalse -Because 'nodes must not have hardcoded IDs'
            $text -match '\bgroupId\s*=' | Should -BeFalse -Because 'nodes must not have hardcoded group IDs'
        }
    }
}
