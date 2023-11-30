function Initialize-CommonInitSetup {
    param ()

    # init
    $script:moduleName = 'PSSymantecSEPM'
    $moduleRootPath = Split-Path -Path $PSScriptRoot -Parent
    $BuildModuleSourcePath = Join-Path -Path $moduleRootPath -ChildPath "Source\PSSymantecSEPM.psd1"
    $MajorMinorPatch = dotnet-gitversion | ConvertFrom-Json | Select-Object -Expand MajorMinorPatch
    $importModulePath = Join-Path -Path $moduleRootPath -ChildPath "Output\PSSymantecSEPM\$MajorMinorPatch\PSSymantecSEPM.psm1"
    $FullSemVer = (dotnet-gitversion | ConvertFrom-Json).FullSemVer
    
    # Build & Import the module
    Build-Module -SourcePath $BuildModuleSourcePath -SemVer $FullSemVer
    Import-Module -Name "$importModulePath" -Force
}

Initialize-CommonInitSetup