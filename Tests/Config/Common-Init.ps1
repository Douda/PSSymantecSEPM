function Initialize-CommonInitSetup {
    param ()

    # init
    $script:moduleName = 'PSSymantecSEPM'
    $moduleRootPath = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent)
    $ModuleManifestFilePath = Join-Path -Path $moduleRootPath -ChildPath "Source\PSSymantecSEPM.psd1"
    $ModuleFilePath = Join-Path -Path $moduleRootPath -ChildPath "Output\PSSymantecSEPM\PSSymantecSEPM.psm1"
    
    # Build & Load the module
    if (-not (Get-Module -ListAvailable -Name "ModuleBuilder")) {
        Write-Verbose "ModuleBuilder Module missing. Installing..." -Verbose
        Install-Module -Name ModuleBuilder -Scope CurrentUser
    } else {
        Build-Module -SourcePath $ModuleManifestFilePath -SemVer 0.0.1
    }
    
    Import-Module -Name "$ModuleFilePath" -Force
    Write-Verbose "Module $script:moduleName loaded" -Verbose
}

Initialize-CommonInitSetup