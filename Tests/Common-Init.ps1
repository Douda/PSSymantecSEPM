function Initialize-CommonInitSetup {
    param ()

    # init
    $script:moduleName = 'PSSymantecSEPM'
    $moduleRootPath = Split-Path -Path $PSScriptRoot -Parent
    $BuildModuleSourcePath = Join-Path -Path $moduleRootPath -ChildPath "Source\PSSymantecSEPM.psd1"
    $importModuleFilePath = Join-Path -Path $moduleRootPath -ChildPath "Output\PSSymantecSEPM\0.0.1\PSSymantecSEPM.psm1"
    
    # If $importModuleFilePath is not found, build the module
    if (!(Test-Path -Path $importModuleFilePath)) {
        Build-Module -SourcePath $BuildModuleSourcePath -SemVer 0.0.1
    }
    Import-Module -Name "$importModuleFilePath" -Force
    Write-Host "Module $script:moduleName loaded"
}

Initialize-CommonInitSetup