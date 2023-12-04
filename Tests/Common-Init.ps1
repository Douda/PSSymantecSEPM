function Initialize-CommonInitSetup {
    param ()

    # init
    $script:moduleName = 'PSSymantecSEPM'
    $moduleRootPath = Split-Path -Path $PSScriptRoot -Parent
    $Build = Join-Path -Path $moduleRootPath -ChildPath "Source\PSSymantecSEPM.psd1"
    $import = Join-Path -Path $moduleRootPath -ChildPath "Output\PSSymantecSEPM\0.0.1\PSSymantecSEPM.psm1"
    
    # If module isn't present on the disk, build it with hardcoded version 0.0.1
    if (!(Test-Path -Path $import)) {
        Build-Module -SourcePath $Build -SemVer 0.0.1
    }
    Import-Module -Name "$import" -Force
    # Write-Host "Module $script:moduleName loaded"
}

Initialize-CommonInitSetup