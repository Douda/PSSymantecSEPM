[CmdletBinding()]
param()

# Build & Load the module
$moduleRootPath = Split-Path -Path $PSScriptRoot -Parent
. (Join-Path -Path $moduleRootPath -ChildPath 'Tests/Config/Common-Init.ps1')

Describe 'Initialize-PolicyExceptionStructure' {
    It 'Returns correct object type' {
        InModuleScope PSSymantecSEPM {
            $script:configurationFilePath = Join-Path -Path 'TestDrive:' -ChildPath 'config.json'
            $script:credentialsFilePath  = Join-Path -Path 'TestDrive:' -ChildPath 'creds.xml'
            $script:accessTokenFilePath  = Join-Path -Path 'TestDrive:' -ChildPath 'token.xml'
            $script:configuration = [PSCustomObject]@{ ServerAddress = 'FakeServer01'; port = '1234'; domain = '' }

            . /home/douda/Documents/Projects/PSSymantecSEPM/Tests/DummyDataGenerator.ps1

            $script:_session = [PSCustomObject]@{
                Headers   = @{ Authorization = 'Bearer FakeToken'; Content = 'application/json' }
                BaseURLv1 = 'https://FakeServer01:1234/sepm/api/v1'
                BaseURLv2 = 'https://FakeServer01:1234/sepm/api/v2'
                SkipCert  = $true
                TokenInfo = [PSCustomObject]@{ token = 'FakeToken'; tokenExpiration = (Get-Date).AddHours(1) }
            }

            Mock Get-SEPMPoliciesSummary {
                return New-DummyDataSEPMPoliciesSummary -PoliciesPerPolicyType 3
            }

            $result = Initialize-PolicyExceptionStructure -PolicyName "policy fw 1"
            $result.ObjBody.PSobject.TypeNames[0] | Should -Be "SEPMPolicyExceptionsStructure"
            $result.ObjBody.name | Should -Be "policy fw 1"
            $result.PolicyID | Should -Not -BeNullOrEmpty
        }
    }
}
