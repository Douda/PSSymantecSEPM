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

function Invoke-WindowsVM {
    <#
    .SYNOPSIS
        Run a PowerShell command on the Windows VM via WinRM (SSL transport).
        Requires pywinrm (Python). VM must have WinRM enabled.
    .EXAMPLE
        Invoke-WindowsVM -Command "Get-Service WinRM"
        Invoke-WindowsVM -Command '$PSVersionTable.PSVersion'
    #>
    param([string]$Command)
    $escaped = $Command -replace "'", "\"'\"" -replace '"', '\"'
    $script = "import winrm; s = winrm.Session('172.17.0.1:5986', auth=('douda', 'aurelien'), transport='ssl', server_cert_validation='ignore'); r = s.run_ps('$escaped'); [print(l.decode().strip()) for l in [r.std_out, r.std_err] if l]"
    python3 -c $script 2>$null
}
