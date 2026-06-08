<#
.SYNOPSIS
    Seeds SEPM with the Groups hierarchy.

.DESCRIPTION
    Reads Source/Seed/Groups.psd1 and creates the full nested group hierarchy
    on the SEPM server. Containers (nodes with children) get inheritance enabled;
    leaves do not. Idempotent — skips groups that already exist.

.PARAMETER State
    Shared state hashtable from the orchestrator. Must contain at least:
    - Force (bool): whether to delete and recreate groups.

.EXAMPLE
    Invoke-SeedGroups -State @{ Force = $false }

    Creates all seed groups (idempotent).

.EXAMPLE
    Invoke-SeedGroups -State @{ Force = $true }

    Deletes existing seed groups, then recreates.

.NOTES
    Force reset requires Remove-SEPMGroup, which was fixed in the same
    changeset (it was previously a broken copy-paste of New-SEPMGroup).
#>

#Requires -Version 5.1

function Invoke-SeedGroups {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable] $State
    )

    # Load the Groups data file (relative to the script's directory)
    # On PS7 (repo): Scripts/Seed-Groups.ps1 -> Source/Seed/Groups.psd1
    # On PS5.1 (deployed): Shared/Seed-Groups.ps1 -> Shared/Source/Seed/Groups.psd1
    $scriptDir = Split-Path -Path $PSScriptRoot -Parent
    if (Test-Path (Join-Path -Path $scriptDir -ChildPath 'Source/Seed/Groups.psd1')) {
        $seedDir = Join-Path -Path $scriptDir -ChildPath 'Source/Seed'
    } else {
        # Fallback: assume script is in Shared/ alongside Source/Seed/
        $seedDir = Join-Path -Path $PSScriptRoot -ChildPath 'Source/Seed'
    }
    $data = Import-PowerShellDataFile -Path (Join-Path -Path $seedDir -ChildPath 'Groups.psd1') -ErrorAction Stop

    # State table: fullPathName -> group ID
    $groupMap = @{}

    # Get all existing groups (for idempotency check)
    $existingGroups = Get-SEPMGroups

    # ── Force reset: delete existing seed groups bottom-up ──
    if ($State.Force) {
        # Collect all seed fullPathNames from the data tree
        function Collect-Paths {
            param($Nodes, [string]$ParentFullPath)
            $paths = [System.Collections.Generic.List[string]]::new()
            foreach ($node in $Nodes) {
                if ($node -is [string]) {
                    $paths.Add("$ParentFullPath\$node")
                } else {
                    $fp = "$ParentFullPath\$($node.Name)"
                    $paths.Add($fp)
                    if ($node.ContainsKey('Children') -and $node.Children) {
                        foreach ($childPath in (Collect-Paths -Nodes $node.Children -ParentFullPath $fp)) {
                            $paths.Add($childPath)
                        }
                    }
                }
            }
            return $paths.ToArray()
        }

        $seedPaths = Collect-Paths -Nodes $data.Groups -ParentFullPath 'My Company'

        # Sort by depth descending (deepest first)
        $seedPaths = $seedPaths | Sort-Object { ($_ -split '\\').Count } -Descending

        # Delete each seed group
        foreach ($path in $seedPaths) {
            $group = $existingGroups | Where-Object { $_.fullPathName -eq $path } | Select-Object -First 1
            if ($group -and $group.id -ne 'mc-id' -and $group.id -ne 'def-id') {
                $parts = $path -split '\\'
                $groupName = $parts[-1]
                $parentPath = $parts[0..($parts.Count - 2)] -join '\'
                Remove-SEPMGroup -GroupName $groupName -ParentGroup $parentPath
            }
        }

        # Refresh existing groups list after deletion
        $existingGroups = Get-SEPMGroups
    }

    # Recursive function to create a node and its children
    function Create-GroupNode {
        param(
            $Node,
            [string] $ParentFullPath,
            $ExistingGroups,
            [hashtable] $GroupMap
        )

        # String leaf: a simple subgroup name (no Description, no Children key)
        if ($Node -is [string]) {
            $fullPathName = "$ParentFullPath\$Node"
            $exists = $ExistingGroups | Where-Object { $_.fullPathName -eq $fullPathName } | Select-Object -First 1

            if (-not $exists) {
                $resp = New-SEPMGroup -GroupName $Node -ParentGroup $ParentFullPath -Description $Node
                $GroupMap[$fullPathName] = $resp.id
            } else {
                $GroupMap[$fullPathName] = $exists.id
            }
            return
        }

        # Hashtable node: has Name, Description, and optionally Children
        $fullPathName = "$ParentFullPath\$($Node.Name)"
        $hasChildren = $Node.ContainsKey('Children') -and $Node.Children -and $Node.Children.Count -gt 0

        $exists = $ExistingGroups | Where-Object { $_.fullPathName -eq $fullPathName } | Select-Object -First 1

        if (-not $exists) {
            $resp = New-SEPMGroup -GroupName $Node.Name `
                -ParentGroup $ParentFullPath `
                -Description $Node.Description `
                -EnabledInheritance:$hasChildren
            $GroupMap[$fullPathName] = $resp.id
        } else {
            $GroupMap[$fullPathName] = $exists.id
        }

        # Recurse into children
        if ($hasChildren) {
            foreach ($child in $Node.Children) {
                Create-GroupNode -Node $child -ParentFullPath $fullPathName `
                    -ExistingGroups $ExistingGroups -GroupMap $GroupMap
            }
        }
    }

    # Walk top-level nodes (regions) under "My Company"
    foreach ($node in $data.Groups) {
        Create-GroupNode -Node $node -ParentFullPath 'My Company' `
            -ExistingGroups $existingGroups -GroupMap $groupMap
    }

    return @{
        GroupMap = $groupMap
    }
}
