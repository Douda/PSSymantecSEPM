# PSSymantecSEPM — Pester 5 Test Template
#
# Use this file as a starting point for new tests.
# Choose the pattern that matches your cmdlet:
#   - PUBLIC function: no InModuleScope, mock boundaries with -ModuleName
#   - PRIVATE function: InModuleScope inside It blocks

[CmdletBinding()]
param()

# ============================================================================
# PUBLIC FUNCTION PATTERN
# ============================================================================
# For cmdlets exported by the module. Test through the public interface.
# Mock the system boundaries (Initialize-SEPMSession, Invoke-ABRestMethod) using
# -ModuleName PSSymantecSEPM. No InModuleScope needed.

Describe 'MyPublicCommand' {
    BeforeDiscovery {
        $moduleRootPath = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
        . (Join-Path -Path $moduleRootPath -ChildPath 'Tests/Config/Common-Init.ps1')
    }

    BeforeAll {
        $moduleRootPath = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
        . (Join-Path -Path $moduleRootPath -ChildPath 'Tests/Config/Common-BeforeAll.ps1')
    }

    AfterAll {
        $moduleRootPath = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
        . (Join-Path -Path $moduleRootPath -ChildPath 'Tests/Config/Common-AfterAll.ps1')
    }

    Context 'basic behavior' {
        It 'Test 1' -Pending {
            # Mock the module boundaries with -ModuleName
            # Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }
            # Mock Invoke-ABRestMethod -ModuleName PSSymantecSEPM { return $fakeResponse }

            $result = MyPublicCommand
            $result | Should -Be "Expected"
        }
    }
}

# ============================================================================
# PRIVATE FUNCTION PATTERN
# ============================================================================
# For module-internal functions. InModuleScope is placed inside individual
# It blocks (never around Describe). Use BeforeAll/AfterAll with InModuleScope
# when module-scoped state setup is needed.

Describe 'MyPrivateFunction' {
    BeforeDiscovery {
        $moduleRootPath = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
        . (Join-Path -Path $moduleRootPath -ChildPath 'Tests/Config/Common-Init.ps1')
    }

    BeforeAll {
        InModuleScope PSSymantecSEPM {
            $moduleRootPath = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
            . (Join-Path -Path $moduleRootPath -ChildPath 'Tests/Config/Common-BeforeAll.ps1')
        }
    }

    AfterAll {
        InModuleScope PSSymantecSEPM {
            $moduleRootPath = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
            . (Join-Path -Path $moduleRootPath -ChildPath 'Tests/Config/Common-AfterAll.ps1')
        }
    }

    Context 'basic behavior' {
        It 'Test 1' -Pending {
            InModuleScope PSSymantecSEPM {
                # Access module-scoped variables and call private functions directly
                $result = MyPrivateFunction
                $result | Should -Be "Expected"
            }
        }
    }
}

# ============================================================================
# NOTES
# ============================================================================
# - Use $state = @{ callCount = 0 } with $state.callCount++ inside Mock for
#   mutable counters (Pester 5 mock closure limitation).
# - Always use -ModuleName PSSymantecSEPM on Mock and Should -Invoke.
# - Use Should -Invoke (Pester 5) instead of Assert-MockCalled (Pester 4).
# - TestDrive: is available for file I/O isolation.
# - Template files are in Tests/Template/ subdirectory, so Split-Path must go
#   up two levels (via double Split-Path -Parent) to reach the repo root.
# - Regular test files in Tests/ need only one Split-Path -Parent.
# - $PSScriptRoot is NOT available in BeforeDiscovery on some Pester 5 versions;
#   the template above computes it from the test file path.
