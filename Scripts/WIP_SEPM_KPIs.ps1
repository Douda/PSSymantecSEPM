<#
.SYNOPSIS
    Scripts to gather SEPM KPIs
    Exports data in a formatted xlsx format
.DESCRIPTION
    Scripts to gather SEPM KPIs
    Exports data in a formatted xlsx format
.PARAMETER Path
    Path of the xlsx file to export
.OUTPUTS
    xlsx formatted report
.NOTES
    Created by: Aurélien BOUMANNE (09182023)
.EXAMPLE
    .\SEPM_KPI.ps1 -Path C:\Data\SEPM_KPIs.xlsx
#>
param (
    # Path of Export
    [Parameter(
        # Mandatory
    )]
    [string]
    # TODO remove hardcoded path
    $Path = ".\Data\SEPM_KPIs.xlsx"
)

# List of KPIs that can be used and scripted

# TODO finish the list & script it
# Total number of clients
# Total number of clients with definitions older than X days
# SEP Clients versions
# Malware detected in the last 30 days
# SEP Clients with Infected status
# Patch Management Compliance
# Policy Compliance / Violations
# Audit Log
# Other ideas?

# Total number of clients
$Computers = Get-SEPComputers

# Total number of clients with definitions older than X days
# Using SepClientOldDefinitions script
$ComputersAVDefsOlderThan7Days = .\SepClientOldDefinitions.ps1 -Days 7

# SEP Clients versions
$SEPClientVersions = (Get-SEPClientVersion).clientVersionList
$chart = New-ExcelChartDefinition -XRange version -YRange clientsCount -Title "SEP Client versions" -NoLegend

# SEP Clients with Infected status
$ComputersInfected = $Computers | Where-Object { $_.infected -eq 1 }


# Exporting data to Excel
$excel_params = @{
    Path         = $Path
    ClearSheet   = $true
    BoldTopRow   = $true
    AutoSize     = $true
    FreezeTopRow = $true
    AutoFilter   = $true
}

$SEPClientVersions             | ConvertTo-FlatObject | Export-Excel -WorksheetName "SEP_Versions" @excel_params -ExcelChartDefinition $chart -Show
$ComputersAVDefsOlderThan7Days | ConvertTo-FlatObject | Export-Excel -WorksheetName "SEP_Old_Defs" @excel_params
$ComputersInfected             | ConvertTo-FlatObject | Export-Excel -WorksheetName "SEP_Infected" @excel_params
$Computers                     | ConvertTo-FlatObject | Export-Excel -WorksheetName "SEP_Raw"      @excel_params

# Charting the data
# $SEPClientVersions | Export-Excel -Path $Path -ExcelChartDefinition $chart -WorksheetName "SEP_Versions" -Show