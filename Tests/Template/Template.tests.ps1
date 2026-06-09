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
# Mock the system boundaries (Initialize-SEPMSession, Invoke-SepmApi) using
# -ModuleName PSSymantecSEPM. No InModuleScope needed.

Describe 'MyPublicCommand' {
    BeforeAll {
        # Import TestHelpers and initialize the test environment.
        # Initialize-TestEnvironment builds+imports the module, resets state,
        # and redirects file paths to TestDrive: automatically.
        $testHelpersRoot = Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath 'TestHelpers'
        Import-Module -Name (Join-Path -Path $testHelpersRoot -ChildPath 'PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
    }

    Context 'basic behavior' {
        It 'Test 1' -Pending {
            # Mock the module boundaries with -ModuleName
            # Mock Initialize-SEPMSession -ModuleName PSSymantecSEPM { return $fakeSession }
            # Mock Invoke-SepmApi -ModuleName PSSymantecSEPM { return $fakeResponse }

            $result = MyPublicCommand
            $result | Should -Be "Expected"
        }
    }
}

# ============================================================================
# PRIVATE FUNCTION PATTERN
# ============================================================================
# For module-internal functions. InModuleScope is placed inside individual
# It blocks (never around Describe). Use BeforeAll/AfterAll without InModuleScope
# — the lifecycle functions handle module initialization internally.

Describe 'MyPrivateFunction' {
    BeforeAll {
        # Import TestHelpers and initialize the test environment.
        # Initialize-TestEnvironment builds+imports the module, resets state,
        # and redirects file paths to TestDrive: automatically.
        $testHelpersRoot = Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath 'TestHelpers'
        Import-Module -Name (Join-Path -Path $testHelpersRoot -ChildPath 'PSSymantecSEPM.TestHelpers.psd1') -Force
        $script:TestState = Initialize-TestEnvironment
    }

    AfterAll {
        Clear-TestEnvironment -State $script:TestState
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
# - Template files are in Tests/Template/ subdirectory, so Split-Path -Parent
#   reaches Tests/ where TestHelpers/ lives.
# - Regular test files in Tests/ use $PSScriptRoot directly for the TestHelpers path.
# - $PSScriptRoot is NOT available in BeforeDiscovery on some Pester 5 versions;
#   the template uses BeforeAll for all setup.
