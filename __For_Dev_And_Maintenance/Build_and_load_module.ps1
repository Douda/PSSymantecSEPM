# Setting up Paths & Variables
$ModuleDevPath = Split-Path -Path $PSScriptRoot -Parent
$BuildModuleSourcePath = $ModuleDevPath + "\Source\PSSymantecSEPM.psd1"
# $MajorMinorPatch = dotnet-gitversion | ConvertFrom-Json | Select-Object -Expand MajorMinorPatch

switch ($true) {
    { $isLinux } {
        $FullSemVer = gitversion | ConvertFrom-Json | Select-Object -ExpandProperty FullSemVer
    }
    { $isWindows } {
        $FullSemVer = dotnet-gitversion | ConvertFrom-Json | Select-Object -ExpandProperty FullSemVer
    }
    default {
        Write-Host "Invalid platform"
    }
}

# $ImportModulePath = $ModuleDevPath + "\Output\PSSymantecSEPM\" + $MajorMinorPatch + "\PSSymantecSEPM.psm1"
$ImportModulePath = $ModuleDevPath + "\Output\PSSymantecSEPM\PSSymantecSEPM.psm1"

# Build Module
Build-Module -SourcePath $BuildModuleSourcePath -SemVer $FullSemVer
Import-Module -Name "$ImportModulePath" -Force
