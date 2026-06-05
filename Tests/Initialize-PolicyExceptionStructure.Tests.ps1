[CmdletBinding()]
param()

Describe 'Initialize-PolicyExceptionStructure' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment

        InModuleScope PSSymantecSEPM {
            $script:configurationFilePath = Join-Path -Path 'TestDrive:' -ChildPath 'config.json'
            $script:credentialsFilePath  = Join-Path -Path 'TestDrive:' -ChildPath 'creds.xml'
            $script:accessTokenFilePath  = Join-Path -Path 'TestDrive:' -ChildPath 'token.xml'
            $script:configuration = [PSCustomObject]@{ ServerAddress = 'FakeServer01'; port = '1234'; domain = '' }
        }
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    It 'Returns correct object type' {
        InModuleScope PSSymantecSEPM {
            $script:_session = New-TestSession -SkipCert

            Mock Get-SEPMPoliciesSummary {
                return New-DummyPolicySummary -PoliciesPerPolicyType 3
            }

            $result = Initialize-PolicyExceptionStructure -PolicyName "policy fw 1"
            $result.ObjBody.PSobject.TypeNames[0] | Should -Be "SEPMPolicyExceptionsStructure"
            $result.ObjBody.name | Should -Be "policy fw 1"
            $result.PolicyID | Should -Not -BeNullOrEmpty
        }
    }
}
