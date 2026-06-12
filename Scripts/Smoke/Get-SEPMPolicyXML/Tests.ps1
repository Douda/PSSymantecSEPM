<#
.SYNOPSIS
    Shared smoke tests for Get-SEPMPolicyXML.

.DESCRIPTION
    Dot-sourced by run.ps7.ps1 and run.ps51.ps1 after Common.ps1.
    Covers: retrieve policy XML by name.
#>

$results = @{}

# ── A1: Retrieve policy XML by name ──
$results.A1 = T "A1" "Get-SEPMPolicyXML by name returns XmlDocument" `
    { Get-SEPMPolicyXML -PolicyName "Firewall policy" } `
    { param($r)
        $r -ne $null -and
        $r -is [System.Xml.XmlDocument]
    }

Write-Summary -Results $results -Label "Get-SEPMPolicyXML Smoke Tests"
