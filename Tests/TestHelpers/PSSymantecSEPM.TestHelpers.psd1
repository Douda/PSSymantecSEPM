@{
    RootModule        = 'PSSymantecSEPM.TestHelpers.psm1'
    ModuleVersion     = '0.0.1'
    GUID              = 'ad416bdd-d561-4e51-9afe-f19a705300be'
    Author            = 'PSSymantecSEPM Contributors'
    Description       = 'Test fixtures, lifecycle functions, and dummy data generators for PSSymantecSEPM tests'
    PowerShellVersion = '5.1'
    FunctionsToExport = @(
        'Initialize-TestEnvironment'
        'Clear-TestEnvironment'
        'New-TestSession'
        'New-DummyComputer'
        'New-DummyPolicySummary'
    )
    PrivateData       = @{
        PSData = @{
            Tags         = @('Pester', 'Testing', 'PSSymantecSEPM')
            ProjectUri   = ''
            LicenseUri   = ''
            ReleaseNotes = ''
        }
    }
}
