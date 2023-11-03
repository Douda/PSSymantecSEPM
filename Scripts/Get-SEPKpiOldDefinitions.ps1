<# 
.SYNOPSIS
    Displays SEP Clients with old definitions
.DESCRIPTION
    Displays SEP Clients with old definitions. 
    By default, clients with definitions older than 7 days are displayed.
.NOTES
    Created by: Aurélien BOUMANNE (10192023)
.EXAMPLE
    .\Get-SEPKpiOldDefinitions.ps1 -Days 14
#>

[CmdletBinding()]
param (
    [Parameter()]
    [int]
    $Days = 7
)

$Computers = Get-SEPComputers

# Parsing the AV definition format - eg : 210602017 - yyMMddxxx (xxx is the revision number)
$ComputersWithOldDefs = @()
$format = 'yyMMdd'
foreach ($Computer in $Computers) {
    # Parse the date using avDefsetVersion first 6 digits (yyMMdd) if not null or empty
    if (![String]::IsNullOrEmpty($Computer.avDefsetVersion)) {
        $date = [DateTime]::ParseExact($Computer.avDefsetVersion.Substring(0, 6), $format, $null)
        # if $date is older than $days
        if ($date -lt (Get-Date).AddDays(-$Days)) {
            $ComputersWithOldDefs += $Computer
        }
    }
}

return $ComputersWithOldDefs
