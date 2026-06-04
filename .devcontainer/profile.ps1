# PSSymantecSEPM dev profile
$MaximumFunctionCount = 4096

function prompt {
    $repo = "$PWD"
    if (Test-Path "$repo/Source/PSSymantecSEPM.psd1") {
        "SEPM [$repo]`n$('>' * ($nestedPromptLevel + 1)) "
    } else {
        "PS $PWD$('>' * ($nestedPromptLevel + 1)) "
    }
}

function Build-ModuleLocal {
    param([string]$SemVer = "0.0.1")
    $src = "$PWD/Source/PSSymantecSEPM.psd1"
    if (!(Test-Path $src)) { Write-Error "Run this from the repo root"; return }
    Build-Module -SourcePath $src -SemVer $SemVer
    $mod = Get-ChildItem -Path "$PWD/Output/PSSymantecSEPM" -Directory | Sort-Object Name -Descending | Select-Object -First 1
    if ($mod) {
        Import-Module "$($mod.FullName)/PSSymantecSEPM.psm1" -Force
        Write-Host "Module loaded from $($mod.FullName)" -ForegroundColor Green
    }
}
