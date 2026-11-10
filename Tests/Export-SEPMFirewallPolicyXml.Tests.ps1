[CmdletBinding()]
param()

Describe 'Export-SEPMFirewallPolicyXml' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context 'happy path' {
        BeforeEach {
            $null = Set-TestMocks -Transport {
                $u = if ($PSBoundParameters['Uri']) { $PSBoundParameters['Uri'] } else { $args -join ' ' }
                if ($u -match '/policies/summary') {
                    return @{ content = @(
                        [PSCustomObject]@{ name = 'Policy One'; id = 'ID-001'; policytype = 'fw' },
                        [PSCustomObject]@{ name = 'Policy Two'; id = 'ID-002'; policytype = 'fw' }
                    ) }
                }
                if ($u -match '/policies/raw/fw/(?<id>\S+)') {
                    return @{ policy_xml = "<Policy Id='$($Matches.id)'><Raw/></Policy>" }
                }
                throw "Unexpected URI: $u"
            }
            $outDir = Join-Path -Path $TestDrive -ChildPath "export-$([Guid]::NewGuid().ToString('N'))"
        }

        It 'writes one file per policy and returns file info objects' {
            $result = Export-SEPMFirewallPolicyXml -OutputDir $outDir

            $result.Count | Should -Be 2
            (@($result | ForEach-Object Name)) -join ',' | Should -Be 'Policy One,Policy Two'
            (@($result | ForEach-Object PolicyId)) -join ',' | Should -Be 'ID-001,ID-002'
            (@($result | ForEach-Object { $_.Bytes -gt 0 }) -contains $false) | Should -BeFalse
        }

        It 'writes the API policy_xml content verbatim, UTF-8 without BOM' {
            $result = Export-SEPMFirewallPolicyXml -OutputDir $outDir

            $file = Join-Path -Path (Join-Path -Path $outDir -ChildPath 'firewall_policy_xml') -ChildPath 'Policy One.xml'
            $file | Should -Exist
            $result[0].Path | Should -Be $file
            Get-Content -Path $file -Raw | Should -Be "<Policy Id='ID-001'><Raw/></Policy>"
            ([System.IO.File]::ReadAllBytes($file))[0] | Should -Be 60  # '<' — no UTF-8 BOM
        }

        It 'fetches summary once and raw XML once per policy' {
            Export-SEPMFirewallPolicyXml -OutputDir $outDir | Out-Null
            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Times 1 -Exactly -ParameterFilter {
                $Uri -match '/policies/summary'
            }
            Should -Invoke Invoke-SepmApi -ModuleName PSSymantecSEPM -Times 2 -Exactly -ParameterFilter {
                $Uri -match '/policies/raw/fw/'
            }
        }

        It 'defaults OutputDir to the current directory' {
            Push-Location $TestDrive
            try {
                Export-SEPMFirewallPolicyXml | Out-Null
                (Join-Path -Path $TestDrive -ChildPath 'firewall_policy_xml') | Should -Exist
            } finally {
                Pop-Location
            }
        }
    }

    Context 'file naming' {
        It 'replaces Windows-invalid filename characters with a dash' {
            $null = Set-TestMocks -Transport {
                $u = if ($PSBoundParameters['Uri']) { $PSBoundParameters['Uri'] } else { $args -join ' ' }
                if ($u -match '/policies/summary') {
                    return @{ content = @(
                        [PSCustomObject]@{ name = 'DWP\A:B*C'; id = 'ID-X'; policytype = 'fw' }
                    ) }
                }
                return @{ policy_xml = '<root />' }
            }
            $outDir = Join-Path -Path $TestDrive -ChildPath 'sanitize'

            $result = Export-SEPMFirewallPolicyXml -OutputDir $outDir 3> $null

            $result[0].Path | Should -BeLike '*DWP-A-B-C.xml'
            (Get-ChildItem -Path (Join-Path -Path $outDir -ChildPath 'firewall_policy_xml'))[0].Name | Should -Be 'DWP-A-B-C.xml'
        }

        It 'appends the policy ID on duplicate names' {
            $null = Set-TestMocks -Transport {
                $u = if ($PSBoundParameters['Uri']) { $PSBoundParameters['Uri'] } else { $args -join ' ' }
                if ($u -match '/policies/summary') {
                    return @{ content = @(
                        [PSCustomObject]@{ name = 'Same Name'; id = 'ID-A'; policytype = 'fw' },
                        [PSCustomObject]@{ name = 'Same Name'; id = 'ID-B'; policytype = 'fw' }
                    ) }
                }
                return @{ policy_xml = '<root />' }
            }
            $outDir = Join-Path -Path $TestDrive -ChildPath 'dupe'

            $result = Export-SEPMFirewallPolicyXml -OutputDir $outDir 3> $null

            $result[0].Path | Should -BeLike '*Same Name.xml'
            $result[1].Path | Should -BeLike '*Same Name_ID-B.xml'
        }
    }

    Context 'failures' {
        It 'warns on a failed policy, continues with the rest' {
            $null = Set-TestMocks -Transport {
                $u = if ($PSBoundParameters['Uri']) { $PSBoundParameters['Uri'] } else { $args -join ' ' }
                if ($u -match '/policies/summary') {
                    return @{ content = @(
                        [PSCustomObject]@{ name = 'Policy One'; id = 'ID-001'; policytype = 'fw' },
                        [PSCustomObject]@{ name = 'Policy Two'; id = 'ID-002'; policytype = 'fw' }
                    ) }
                }
                if ($u -match '/policies/raw/fw/ID-001') { throw 'boom' }
                return @{ policy_xml = '<ok />' }
            }
            $outDir = Join-Path -Path $TestDrive -ChildPath 'partial'

            $result = Export-SEPMFirewallPolicyXml -OutputDir $outDir 3> $null

            @($result).Count | Should -Be 1
            @($result)[0].Name | Should -Be 'Policy Two'
        }

        It 'returns an empty array when no firewall policies exist' {
            $null = Set-TestMocks -Transport {
                $u = if ($PSBoundParameters['Uri']) { $PSBoundParameters['Uri'] } else { $args -join ' ' }
                if ($u -match '/policies/summary') { return @{ content = @() } }
                throw 'should not be called'
            }

            $result = Export-SEPMFirewallPolicyXml -OutputDir (Join-Path -Path $TestDrive -ChildPath 'empty') 3> $null

            @($result).Count | Should -Be 0
        }
    }
}
