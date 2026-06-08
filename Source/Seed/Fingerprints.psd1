@{
    Fingerprints = @(
        @{
            Name        = 'Known Malware Hashes'
            Description = 'Seed data — simulated malware hashes'
            HashType    = 'SHA256'
            Data        = @(
                '0000000000000000000000000000000000000000000000000000000000000001'
                '0000000000000000000000000000000000000000000000000000000000000002'
                '0000000000000000000000000000000000000000000000000000000000000003'
                '0000000000000000000000000000000000000000000000000000000000000004'
                '0000000000000000000000000000000000000000000000000000000000000005'
            )
        }
        @{
            Name        = 'Approved Binaries'
            Description = 'Seed data — simulated approved binaries'
            HashType    = 'SHA256'
            Data        = @(
                'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA1'
                'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA2'
                'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA3'
            )
        }
    )
}
