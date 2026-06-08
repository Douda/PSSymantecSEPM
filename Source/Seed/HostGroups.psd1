@{
    HostGroups = @(
        @{
            Name = 'Corporate LAN'
            Hosts = @(
                @{ ipv4_subnet = @{ ip = '10.0.0.0'; mask = '255.0.0.0' } }
                @{ ipv4_subnet = @{ ip = '172.16.0.0'; mask = '255.240.0.0' } }
                @{ ip = '192.168.1.1' }
            )
        }
        @{
            Name = 'DMZ Servers'
            Hosts = @(
                @{ ipv4_subnet = @{ ip = '192.168.100.0'; mask = '255.255.255.0' } }
                @{ ip = '10.0.0.100' }
            )
        }
    )
}
