function Export-SEPMFirewallPolicyXml {
    <#
    .SYNOPSIS
        Exports all firewall policies as raw XML files.

    .DESCRIPTION
        Fetches the firewall policy list via the policy summary endpoint, then
        retrieves each policy's raw XML via the /policies/raw/fw/{id} endpoint
        and writes it unmodified to <OutputDir>\firewall_policy_xml.

        Files are named after the SEPM policy name. Characters invalid in
        Windows filenames ( \ / : * ? " < > | and control chars ) are replaced
        with '-'; a name collision gets the policy ID appended. Renames and
        failures are reported as warnings; a failed policy does not stop the run.

        API calls: one policy summary + one raw XML request per firewall policy.

    .PARAMETER OutputDir
        Directory to export into. The firewall_policy_xml subfolder is created
        inside it. Defaults to the current directory.

    .OUTPUTS
        One PSCustomObject (Name, PolicyId, Path, Bytes) per successfully
        written policy, as a non-enumerated array.

    .EXAMPLE
        PS C:\> Export-SEPMFirewallPolicyXml

        Exports all firewall policies to .\firewall_policy_xml.

    .EXAMPLE
        PS C:\> Export-SEPMFirewallPolicyXml -OutputDir C:\temp\fw | Format-Table Name, Bytes

        Exports to C:\temp\fw\firewall_policy_xml and lists the results.
    #>

    [CmdletBinding()]
    param (
        [Parameter()]
        [string]$OutputDir = (Get-Location).Path
    )

    begin {
        $session = Initialize-SEPMSession
        $summaryEndpoint = Get-SEPMApiEndpoint -OperationName 'Get-SEPMPoliciesSummary'
        $rawEndpoint = Get-SEPMApiEndpoint -OperationName 'Get-SEPMPolicyXML'
    }

    process {
        try {
            $summary = Invoke-SepmEndpoint -Endpoint $summaryEndpoint -Session $session -PathIds @('fw')
        } catch {
            Write-Error "Failed to fetch firewall policy summary: $_"
            return
        }

        $fwPolicies = @($summary.content | Where-Object { $_.policytype -eq 'fw' })
        if ($fwPolicies.Count -eq 0) {
            Write-Warning 'No firewall policies found.'
            return Write-Output @() -NoEnumerate
        }

        $dir = Join-Path -Path $OutputDir -ChildPath 'firewall_policy_xml'
        if (-not (Test-Path -Path $dir)) {
            $null = New-Item -ItemType Directory -Path $dir -Force
        }

        $written = @()
        $seen = @{}
        $i = 0
        foreach ($policy in $fwPolicies) {
            $i++
            Write-Verbose "  -> FirewallPolicyXml ($i/$($fwPolicies.Count)): $($policy.name)"
            try {
                $resp = Invoke-SepmEndpoint -Endpoint $rawEndpoint -Session $session -PathIds @('fw', $policy.id)
                $rawXml = $resp.policy_xml
                if (-not $rawXml) { throw 'Empty policy_xml in response' }

                # Windows-invalid filename chars + control chars -> '-'
                $base = $policy.name -replace '[\\/:*?"<>|\x00-\x1F]', '-'
                if ($base -ne $policy.name) {
                    Write-Warning "Policy name '$($policy.name)' sanitized to file name '$base.xml'"
                }
                $fileName = "$base.xml"
                if ($seen.ContainsKey($fileName)) {
                    $fileName = "${base}_$($policy.id).xml"
                    Write-Warning "Duplicate policy name; file name becomes '$fileName'"
                }
                $seen[$fileName] = $true

                $filePath = Join-Path -Path $dir -ChildPath $fileName
                # Exact string payload, UTF-8 without BOM, no trailing newline.
                [System.IO.File]::WriteAllText($filePath, $rawXml)

                $written += [PSCustomObject]@{
                    Name     = $policy.name
                    PolicyId = $policy.id
                    Path     = $filePath
                    Bytes    = $rawXml.Length
                }
            } catch {
                Write-Warning "Failed to export policy '$($policy.name)' ($($policy.id)): $($_.Exception.Message)"
            }
        }

        Write-Output $written -NoEnumerate
    }
}
