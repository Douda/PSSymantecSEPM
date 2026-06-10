@{
    Groups = @(
        @{
            Name        = 'EMEA'
            Description = 'Region - EMEA'
            Children    = @(
                @{
                    Name        = 'UK'
                    Description = 'Country - UK'
                    Children    = @(
                        @{
                            Name        = 'London'
                            Description = 'City - London'
                            Children    = @(
                                @{ Name = 'Servers'; Description = 'Leaf - Servers' }
                                @{
                                    Name        = 'Workstations'
                                    Description = 'Leaf - HR Exception Machines subgroup'
                                    Children    = @('HR Exception Machines')
                                }
                            )
                        }
                        @{
                            Name        = 'Manchester'
                            Description = 'City - Manchester'
                            Children    = @(
                                @{ Name = 'Servers'; Description = 'Leaf - Servers' }
                                @{
                                    Name        = 'Workstations'
                                    Description = 'Leaf - Small Office subgroup'
                                    Children    = @('Small Office')
                                }
                            )
                        }
                    )
                }
                @{
                    Name        = 'Germany'
                    Description = 'Country - Germany'
                    Children    = @(
                        @{
                            Name        = 'Berlin'
                            Description = 'City - Berlin'
                            Children    = @(
                                @{ Name = 'Servers'; Description = 'Leaf - Servers' }
                                @{
                                    Name        = 'Workstations'
                                    Description = 'Leaf - Entrance Office subgroup'
                                    Children    = @('Entrance Office')
                                }
                            )
                        }
                        @{
                            Name        = 'Munich'
                            Description = 'City - Munich'
                            Children    = @(
                                @{ Name = 'Servers'; Description = 'Leaf - Servers' }
                                @{ Name = 'Workstations'; Description = 'Leaf - Workstations' }
                            )
                        }
                    )
                }
                @{
                    Name        = 'France'
                    Description = 'Country - France'
                    Children    = @(
                        @{
                            Name        = 'Paris'
                            Description = 'City - Paris'
                            Children    = @(
                                @{ Name = 'Servers'; Description = 'Leaf - Servers' }
                                @{
                                    Name        = 'Workstations'
                                    Description = 'Leaf - Developers subgroup'
                                    Children    = @('Developers')
                                }
                            )
                        }
                        @{
                            Name        = 'Lyon'
                            Description = 'City - Lyon'
                            Children    = @(
                                @{ Name = 'Servers'; Description = 'Leaf - Servers' }
                                @{
                                    Name        = 'Workstations'
                                    Description = 'Leaf - Executives subgroup'
                                    Children    = @('Executives')
                                }
                            )
                        }
                    )
                }
                @{
                    Name        = 'Spain'
                    Description = 'Country - Spain'
                    Children    = @(
                        @{
                            Name        = 'Madrid'
                            Description = 'City - Madrid'
                            Children    = @(
                                @{ Name = 'Servers'; Description = 'Leaf - Servers' }
                                @{ Name = 'Workstations'; Description = 'Leaf - Workstations' }
                            )
                        }
                        @{
                            Name        = 'Barcelona'
                            Description = 'City - Barcelona'
                            Children    = @(
                                @{ Name = 'Servers'; Description = 'Leaf - Servers' }
                                @{
                                    Name        = 'Workstations'
                                    Description = 'Leaf - Developers subgroup'
                                    Children    = @('Developers')
                                }
                            )
                        }
                    )
                }
                @{
                    Name        = 'Italy'
                    Description = 'Country - Italy'
                    Children    = @(
                        @{
                            Name        = 'Rome'
                            Description = 'City - Rome'
                            Children    = @(
                                @{ Name = 'Servers'; Description = 'Leaf - Servers' }
                                @{
                                    Name        = 'Workstations'
                                    Description = 'Leaf - Executives subgroup'
                                    Children    = @('Executives')
                                }
                            )
                        }
                        @{
                            Name        = 'Milan'
                            Description = 'City - Milan'
                            Children    = @(
                                @{ Name = 'Servers'; Description = 'Leaf - Servers' }
                                @{ Name = 'Workstations'; Description = 'Leaf - Workstations' }
                            )
                        }
                    )
                }
            )
        }
        @{
            Name        = 'NA'
            Description = 'Region - NA'
            Children    = @(
                @{
                    Name        = 'US'
                    Description = 'Country - US'
                    Children    = @(
                        @{
                            Name        = 'New York'
                            Description = 'City - New York'
                            Children    = @(
                                @{ Name = 'Servers'; Description = 'Leaf - Servers' }
                                @{
                                    Name        = 'Workstations'
                                    Description = 'Leaf - HR Exception Machines subgroup'
                                    Children    = @('HR Exception Machines')
                                }
                            )
                        }
                        @{
                            Name        = 'San Francisco'
                            Description = 'City - San Francisco'
                            Children    = @(
                                @{ Name = 'Servers'; Description = 'Leaf - Servers' }
                                @{
                                    Name        = 'Workstations'
                                    Description = 'Leaf - Entrance Office subgroup'
                                    Children    = @('Entrance Office')
                                }
                            )
                        }
                    )
                }
                @{
                    Name        = 'Canada'
                    Description = 'Country - Canada'
                    Children    = @(
                        @{
                            Name        = 'Toronto'
                            Description = 'City - Toronto'
                            Children    = @(
                                @{ Name = 'Servers'; Description = 'Leaf - Servers' }
                                @{
                                    Name        = 'Workstations'
                                    Description = 'Leaf - Small Office subgroup'
                                    Children    = @('Small Office')
                                }
                            )
                        }
                        @{
                            Name        = 'Vancouver'
                            Description = 'City - Vancouver'
                            Children    = @(
                                @{ Name = 'Servers'; Description = 'Leaf - Servers' }
                                @{
                                    Name        = 'Workstations'
                                    Description = 'Leaf - Developers subgroup'
                                    Children    = @('Developers')
                                }
                            )
                        }
                    )
                }
                @{
                    Name        = 'Mexico'
                    Description = 'Country - Mexico'
                    Children    = @(
                        @{
                            Name        = 'Mexico City'
                            Description = 'City - Mexico City'
                            Children    = @(
                                @{ Name = 'Servers'; Description = 'Leaf - Servers' }
                                @{ Name = 'Workstations'; Description = 'Leaf - Workstations' }
                            )
                        }
                        @{
                            Name        = 'Monterrey'
                            Description = 'City - Monterrey'
                            Children    = @(
                                @{ Name = 'Servers'; Description = 'Leaf - Servers' }
                                @{ Name = 'Workstations'; Description = 'Leaf - Workstations' }
                            )
                        }
                    )
                }
                @{
                    Name        = 'Brazil'
                    Description = 'Country - Brazil'
                    Children    = @(
                        @{
                            Name        = 'Sao Paulo'
                            Description = 'City - Sao Paulo'
                            Children    = @(
                                @{ Name = 'Servers'; Description = 'Leaf - Servers' }
                                @{
                                    Name        = 'Workstations'
                                    Description = 'Leaf - Executives subgroup'
                                    Children    = @('Executives')
                                }
                            )
                        }
                        @{
                            Name        = 'Rio de Janeiro'
                            Description = 'City - Rio de Janeiro'
                            Children    = @(
                                @{ Name = 'Servers'; Description = 'Leaf - Servers' }
                                @{ Name = 'Workstations'; Description = 'Leaf - Workstations' }
                            )
                        }
                    )
                }
                @{
                    Name        = 'Argentina'
                    Description = 'Country - Argentina'
                    Children    = @(
                        @{
                            Name        = 'Buenos Aires'
                            Description = 'City - Buenos Aires'
                            Children    = @(
                                @{ Name = 'Servers'; Description = 'Leaf - Servers' }
                                @{
                                    Name        = 'Workstations'
                                    Description = 'Leaf - Executives subgroup'
                                    Children    = @('Executives')
                                }
                            )
                        }
                        @{
                            Name        = 'Cordoba'
                            Description = 'City - Cordoba'
                            Children    = @(
                                @{ Name = 'Servers'; Description = 'Leaf - Servers' }
                                @{ Name = 'Workstations'; Description = 'Leaf - Workstations' }
                            )
                        }
                    )
                }
            )
        }
        @{
            Name        = 'APJ'
            Description = 'Region - APJ'
            Children    = @(
                @{
                    Name        = 'Japan'
                    Description = 'Country - Japan'
                    Children    = @(
                        @{
                            Name        = 'Tokyo'
                            Description = 'City - Tokyo'
                            Children    = @(
                                @{ Name = 'Servers'; Description = 'Leaf - Servers' }
                                @{
                                    Name        = 'Workstations'
                                    Description = 'Leaf - HR Exception Machines subgroup'
                                    Children    = @('HR Exception Machines')
                                }
                            )
                        }
                        @{
                            Name        = 'Osaka'
                            Description = 'City - Osaka'
                            Children    = @(
                                @{ Name = 'Servers'; Description = 'Leaf - Servers' }
                                @{ Name = 'Workstations'; Description = 'Leaf - Workstations' }
                            )
                        }
                    )
                }
                @{
                    Name        = 'Australia'
                    Description = 'Country - Australia'
                    Children    = @(
                        @{
                            Name        = 'Sydney'
                            Description = 'City - Sydney'
                            Children    = @(
                                @{ Name = 'Servers'; Description = 'Leaf - Servers' }
                                @{
                                    Name        = 'Workstations'
                                    Description = 'Leaf - Small Office subgroup'
                                    Children    = @('Small Office')
                                }
                            )
                        }
                        @{
                            Name        = 'Melbourne'
                            Description = 'City - Melbourne'
                            Children    = @(
                                @{ Name = 'Servers'; Description = 'Leaf - Servers' }
                                @{ Name = 'Workstations'; Description = 'Leaf - Workstations' }
                            )
                        }
                    )
                }
                @{
                    Name        = 'India'
                    Description = 'Country - India'
                    Children    = @(
                        @{
                            Name        = 'Mumbai'
                            Description = 'City - Mumbai'
                            Children    = @(
                                @{ Name = 'Servers'; Description = 'Leaf - Servers' }
                                @{
                                    Name        = 'Workstations'
                                    Description = 'Leaf - Entrance Office subgroup'
                                    Children    = @('Entrance Office')
                                }
                            )
                        }
                        @{
                            Name        = 'Bangalore'
                            Description = 'City - Bangalore'
                            Children    = @(
                                @{ Name = 'Servers'; Description = 'Leaf - Servers' }
                                @{ Name = 'Workstations'; Description = 'Leaf - Workstations' }
                            )
                        }
                    )
                }
                @{
                    Name        = 'China'
                    Description = 'Country - China'
                    Children    = @(
                        @{
                            Name        = 'Beijing'
                            Description = 'City - Beijing'
                            Children    = @(
                                @{ Name = 'Servers'; Description = 'Leaf - Servers' }
                                @{ Name = 'Workstations'; Description = 'Leaf - Workstations' }
                            )
                        }
                        @{
                            Name        = 'Shanghai'
                            Description = 'City - Shanghai'
                            Children    = @(
                                @{ Name = 'Servers'; Description = 'Leaf - Servers' }
                                @{
                                    Name        = 'Workstations'
                                    Description = 'Leaf - Developers subgroup'
                                    Children    = @('Developers')
                                }
                            )
                        }
                    )
                }
                @{
                    Name        = 'Singapore'
                    Description = 'Country - Singapore'
                    Children    = @(
                        @{
                            Name        = 'Singapore Central'
                            Description = 'City - Singapore Central'
                            Children    = @(
                                @{ Name = 'Servers'; Description = 'Leaf - Servers' }
                                @{
                                    Name        = 'Workstations'
                                    Description = 'Leaf - Executives subgroup'
                                    Children    = @('Executives')
                                }
                            )
                        }
                        @{
                            Name        = 'Singapore East'
                            Description = 'City - Singapore East'
                            Children    = @(
                                @{ Name = 'Servers'; Description = 'Leaf - Servers' }
                                @{ Name = 'Workstations'; Description = 'Leaf - Workstations' }
                            )
                        }
                    )
                }
            )
        }
    )
}
