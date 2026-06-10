@{
    Assignments = @(
        # ═══════════════════════════════════════════════
        # Servers (all cities)
        # ═══════════════════════════════════════════════
        @{
            groupPath  = '*\Servers'
            policyType = 'exceptions'
            policyName = 'Server Exceptions'
        }
        @{
            groupPath  = '*\Servers'
            policyType = 'mem'
            policyName = 'Standard MEM'
        }
        @{
            groupPath  = '*\Servers'
            policyType = 'upgrade'
            policyName = 'Zero-Day Upgrade'
        }
        @{
            groupPath  = '*\Servers'
            policyType = 'tdad'
            policyName = 'TDAD Enabled'
        }

        # ═══════════════════════════════════════════════
        # Workstations (flat — no subgroups)
        # ═══════════════════════════════════════════════
        @{
            groupPath  = '*\Workstations'
            policyType = 'exceptions'
            policyName = 'Standard Workstation Exceptions'
        }
        @{
            groupPath  = '*\Workstations'
            policyType = 'mem'
            policyName = 'Standard MEM'
        }
        @{
            groupPath  = '*\Workstations'
            policyType = 'upgrade'
            policyName = 'Weekend Upgrade'
        }

        # ═══════════════════════════════════════════════
        # HR Exception Machines subgroup
        # ═══════════════════════════════════════════════
        @{
            groupPath  = '*\HR Exception Machines'
            policyType = 'exceptions'
            policyName = 'Developer Exceptions'
        }
        @{
            groupPath  = '*\HR Exception Machines'
            policyType = 'mem'
            policyName = 'Standard MEM'
        }
        @{
            groupPath  = '*\HR Exception Machines'
            policyType = 'upgrade'
            policyName = 'Weekend Upgrade'
        }

        # ═══════════════════════════════════════════════
        # Small Office subgroup
        # ═══════════════════════════════════════════════
        @{
            groupPath  = '*\Small Office'
            policyType = 'exceptions'
            policyName = 'Standard Workstation Exceptions'
        }
        @{
            groupPath  = '*\Small Office'
            policyType = 'mem'
            policyName = 'Standard MEM'
        }
        @{
            groupPath  = '*\Small Office'
            policyType = 'upgrade'
            policyName = 'Manual Upgrade'
        }

        # ═══════════════════════════════════════════════
        # Entrance Office subgroup
        # ═══════════════════════════════════════════════
        @{
            groupPath  = '*\Entrance Office'
            policyType = 'exceptions'
            policyName = 'Standard Workstation Exceptions'
        }
        @{
            groupPath  = '*\Entrance Office'
            policyType = 'mem'
            policyName = 'Advanced MEM'
        }
        @{
            groupPath  = '*\Entrance Office'
            policyType = 'upgrade'
            policyName = 'Weekend Upgrade'
        }
        @{
            groupPath       = '*\Entrance Office'
            policyType      = 'fingerprint'
            fingerprintName = 'Known Malware Hashes'
        }

        # ═══════════════════════════════════════════════
        # Developers subgroup
        # ═══════════════════════════════════════════════
        @{
            groupPath  = '*\Developers'
            policyType = 'exceptions'
            policyName = 'Developer Exceptions'
        }
        @{
            groupPath  = '*\Developers'
            policyType = 'mem'
            policyName = 'Advanced MEM'
        }
        @{
            groupPath  = '*\Developers'
            policyType = 'upgrade'
            policyName = 'Zero-Day Upgrade'
        }

        # ═══════════════════════════════════════════════
        # Executives subgroup
        # ═══════════════════════════════════════════════
        @{
            groupPath  = '*\Executives'
            policyType = 'exceptions'
            policyName = 'Standard Workstation Exceptions'
        }
        @{
            groupPath  = '*\Executives'
            policyType = 'mem'
            policyName = 'Advanced MEM'
        }
        @{
            groupPath  = '*\Executives'
            policyType = 'upgrade'
            policyName = 'Zero-Day Upgrade'
        }
        @{
            groupPath       = '*\Executives'
            policyType      = 'fingerprint'
            fingerprintName = 'Known Malware Hashes'
        }
    )
}
