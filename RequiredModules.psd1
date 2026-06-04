# Required modules for building and testing PSSymantecSEPM
# Install with: Install-RequiredModule
@{
    ModuleBuilder = "1.*"
    Configuration = "1.*"
    Pester        = "5.*"
    PSScriptAnalyzer = "1.*"
    # ImportExcel = "7.8.*"  # Needed for Export-SEPMExceptionPolicyToExcel
}
