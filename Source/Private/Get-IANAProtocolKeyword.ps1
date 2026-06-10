function Get-IANAProtocolKeyword {
    <#
    .SYNOPSIS
        Returns the IANA protocol keyword for a protocol number.
    .DESCRIPTION
        Looks up the protocol number in a static mapping (common protocols) and
        falls back to downloading from IANA if not found. Results are cached in
        script scope.
    .PARAMETER ProtocolNumber
        The IANA protocol number (e.g. 6 for TCP, 17 for UDP).
    .EXAMPLE
        Get-IANAProtocolKeyword -ProtocolNumber 6
        Returns "TCP"
    #>
    param(
        [Parameter(Mandatory = $true)]
        [int]$ProtocolNumber
    )

    # Initialize static cache if needed
    if (-not $script:IANAProtocolCache) {
        $script:IANAProtocolCache = @{
            0   = 'HOPOPT'
            1   = 'ICMP'
            2   = 'IGMP'
            3   = 'GGP'
            4   = 'IPv4'
            5   = 'ST'
            6   = 'TCP'
            7   = 'CBT'
            8   = 'EGP'
            9   = 'IGP'
            10  = 'BBN-RCC-MON'
            11  = 'NVP-II'
            12  = 'PUP'
            13  = 'ARGUS'
            14  = 'EMCON'
            15  = 'XNET'
            16  = 'CHAOS'
            17  = 'UDP'
            18  = 'MUX'
            19  = 'DCN-MEAS'
            20  = 'HMP'
            21  = 'PRM'
            22  = 'XNS-IDP'
            23  = 'TRUNK-1'
            24  = 'TRUNK-2'
            25  = 'LEAF-1'
            26  = 'LEAF-2'
            27  = 'RDP'
            28  = 'IRTP'
            29  = 'ISO-TP4'
            30  = 'NETBLT'
            31  = 'MFE-NSP'
            32  = 'MERIT-INP'
            33  = 'DCCP'
            34  = '3PC'
            35  = 'IDPR'
            36  = 'XTP'
            37  = 'DDP'
            38  = 'IDPR-CMTP'
            39  = 'TP++'
            40  = 'IL'
            41  = 'IPv6'
            42  = 'SDRP'
            43  = 'IPv6-Route'
            44  = 'IPv6-Frag'
            45  = 'IDRP'
            46  = 'RSVP'
            47  = 'GRE'
            48  = 'DSR'
            49  = 'BNA'
            50  = 'ESP'
            51  = 'AH'
            52  = 'I-NLSP'
            53  = 'SWIPE'
            54  = 'NARP'
            55  = 'MOBILE'
            56  = 'TLSP'
            57  = 'SKIP'
            58  = 'ICMPv6'
            59  = 'IPv6-NoNxt'
            60  = 'IPv6-Opts'
            61  = 'any host internal'
            62  = 'CFTP'
            63  = 'any local network'
            64  = 'SAT-EXPAK'
            65  = 'KRYPTOLAN'
            66  = 'RVD'
            67  = 'IPPC'
            68  = 'any distributed filesystem'
            69  = 'SAT-MON'
            70  = 'VISA'
            71  = 'IPCV'
            72  = 'CPNX'
            73  = 'CPHB'
            74  = 'WSN'
            75  = 'PVP'
            76  = 'BR-SAT-MON'
            77  = 'SUN-ND'
            78  = 'WB-MON'
            79  = 'WB-EXPAK'
            80  = 'ISO-IP'
            81  = 'VMTP'
            82  = 'SECURE-VMTP'
            83  = 'VINES'
            84  = 'TTP'
            85  = 'NSFNET-IGP'
            86  = 'DGP'
            87  = 'TCF'
            88  = 'EIGRP'
            89  = 'OSPFIGP'
            90  = 'Sprite-RPC'
            91  = 'LARP'
            92  = 'MTP'
            93  = 'AX.25'
            94  = 'IPIP'
            95  = 'MICP'
            96  = 'SCC-SP'
            97  = 'ETHERIP'
            98  = 'ENCAP'
            99  = 'any private encryption'
            100 = 'GMTP'
            101 = 'IFMP'
            102 = 'PNNI'
            103 = 'PIM'
            104 = 'ARIS'
            105 = 'SCPS'
            106 = 'QNX'
            107 = 'A/N'
            108 = 'IPComp'
            109 = 'SNP'
            110 = 'Compaq-Peer'
            111 = 'IPX-in-IP'
            112 = 'VRRP'
            113 = 'PGM'
            114 = 'any 0-hop'
            115 = 'L2TP'
            116 = 'DDX'
            117 = 'IATP'
            118 = 'STP'
            119 = 'SRP'
            120 = 'UTI'
            121 = 'SMP'
            122 = 'SM'
            123 = 'PTP'
            124 = 'ISIS over IPv4'
            125 = 'FIRE'
            126 = 'CRTP'
            127 = 'CRUDP'
            128 = 'SSCOPMCE'
            129 = 'IPLT'
            130 = 'SPS'
            131 = 'PIPE'
            132 = 'SCTP'
            133 = 'FC'
            134 = 'RSVP-E2E-IGNORE'
            135 = 'Mobility Header'
            136 = 'UDPLite'
            137 = 'MPLS-in-IP'
            138 = 'manet'
            139 = 'HIP'
            140 = 'Shim6'
            141 = 'WESP'
            142 = 'ROHC'
        }
    }

    if ($script:IANAProtocolCache.ContainsKey($ProtocolNumber)) {
        return $script:IANAProtocolCache[$ProtocolNumber]
    }

    # Fallback: try to download from IANA (cached for session)
    if (-not $script:IANADownloadAttempted) {
        $script:IANADownloadAttempted = $true
        try {
            $csv = Invoke-RestMethod -Uri 'https://www.iana.org/assignments/protocol-numbers/protocol-numbers-1.csv' -TimeoutSec 5
            $lines = $csv -split "`n"
            foreach ($line in $lines) {
                if ($line -match '^(\d+),("[^"]*"|[^,]*),') {
                    $num = [int]$Matches[1]
                    $name = $Matches[2] -replace '"', ''
                    if (-not $script:IANAProtocolCache.ContainsKey($num)) {
                        $script:IANAProtocolCache[$num] = $name
                    }
                }
            }
        } catch {
            # Download failed; stick with static cache
        }
    }

    if ($script:IANAProtocolCache.ContainsKey($ProtocolNumber)) {
        return $script:IANAProtocolCache[$ProtocolNumber]
    }

    return "proto$ProtocolNumber"
}
