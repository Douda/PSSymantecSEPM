function Write-InventoryClixml {
    <#
    .SYNOPSIS
        Writes per-category .clixml files and a timestamped snapshot blob from an inventory snapshot.

    .DESCRIPTION
        Walks the snapshot PSCustomObject's properties, skips metadata properties (FetchedAt, Failures),
        converts CamelCase category names to snake_case filenames (e.g. ClientDefVersions → all_client_def_versions.xml),
        and writes each non-null, non-empty-array property via Export-Clixml.
        Finally writes the full snapshot as SepmInventory_<timestamp>.clixml.

    .PARAMETER Snapshot
        The inventory snapshot object of type SEPM.Inventory.

    .PARAMETER OutputDir
        Directory where exported files are written.

    .EXAMPLE
        Write-InventoryClixml -Snapshot $snapshot -OutputDir 'C:\inventory'
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Snapshot,

        [Parameter(Mandatory = $true)]
        [string]$OutputDir
    )

    foreach ($prop in $Snapshot.PSObject.Properties) {
        $propName = $prop.Name
        $propValue = $prop.Value

        # Skip metadata properties
        if ($propName -eq 'FetchedAt' -or $propName -eq 'Failures') {
            continue
        }

        # Skip null values
        if ($null -eq $propValue) {
            continue
        }

        # Skip empty arrays
        $isArray = $propValue -is [System.Collections.IList] -or $propValue -is [array]
        if ($isArray -and $propValue.Count -eq 0) {
            continue
        }

        # Convert CamelCase to snake_case for filename
        $snakeName = Convert-CamelToSnake -Name $propName
        $filename = "all_$snakeName.xml"
        $filePath = Join-Path -Path $OutputDir -ChildPath $filename

        $propValue | Export-Clixml -Path $filePath -Force
    }

    # Write timestamped snapshot blob
    $timestamp = $Snapshot.FetchedAt.ToString('yyyy-MM-ddTHH-mm-ss')
    $blobFilename = "SepmInventory_$timestamp.clixml"
    $blobPath = Join-Path -Path $OutputDir -ChildPath $blobFilename
    $Snapshot | Export-Clixml -Path $blobPath -Force
}
