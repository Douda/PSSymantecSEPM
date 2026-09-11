[CmdletBinding()]
param()

Describe 'New-SEPMApiError' {
    BeforeAll {
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers/PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    It 'returns an ErrorRecord' {
        InModuleScope PSSymantecSEPM {
            $result = New-SEPMApiError -Message 'something failed'
            $result | Should -BeOfType ([System.Management.Automation.ErrorRecord])
        }
    }

    It 'stores the message' {
        InModuleScope PSSymantecSEPM {
            (New-SEPMApiError -Message 'something failed').Exception.Message | Should -Be 'something failed'
        }
    }

    It 'defaults the ErrorId to SEPM.ApiError' {
        InModuleScope PSSymantecSEPM {
            (New-SEPMApiError -Message 'm').FullyQualifiedErrorId | Should -BeLike 'SEPM.ApiError*'
        }
    }

    It 'honours an explicit ErrorId' {
        InModuleScope PSSymantecSEPM {
            (New-SEPMApiError -Message 'm' -ErrorId 'SEPM.AuthenticationFailed').FullyQualifiedErrorId |
                Should -BeLike 'SEPM.AuthenticationFailed*'
        }
    }

    It 'defaults the category to ConnectionError' {
        InModuleScope PSSymantecSEPM {
            (New-SEPMApiError -Message 'm').CategoryInfo.Category | Should -Be 'ConnectionError'
        }
    }

    It 'honours an explicit category' {
        InModuleScope PSSymantecSEPM {
            $result = New-SEPMApiError -Message 'm' -Category ([System.Management.Automation.ErrorCategory]::InvalidData)
            $result.CategoryInfo.Category | Should -Be 'InvalidData'
        }
    }

    It 'stores the target' {
        InModuleScope PSSymantecSEPM {
            (New-SEPMApiError -Message 'm' -Target 'https://sepm/api').TargetObject | Should -Be 'https://sepm/api'
        }
    }

    It 'keeps the ErrorId matchable with -like once thrown' {
        InModuleScope PSSymantecSEPM {
            # PowerShell composes FullyQualifiedErrorId as '<ErrorId>,<ExceptionType>', which is why
            # callers match with -like rather than -eq.
            try {
                throw (New-SEPMApiError -Message 'm' -ErrorId 'SEPM.CertificateError')
            } catch {
                $_.FullyQualifiedErrorId | Should -BeLike 'SEPM.CertificateError*'
            }
        }
    }
}
