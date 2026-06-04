# PSSymantecSEPM Development Container
# Uses PowerShell 7+ with dev tools pre-installed
FROM mcr.microsoft.com/powershell:latest

# Install system tools useful for API debugging and development
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    jq \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Switch to PowerShell for module installation
SHELL ["/usr/bin/pwsh", "-c"]

# Install required PowerShell modules for development
RUN $ErrorActionPreference = 'Stop'; \
    $modules = @( \
        'ModuleBuilder', \
        'Pester', \
        'PSScriptAnalyzer', \
        'PlatyPS' \
    ); \
    foreach ($m in $modules) { \
        Write-Host "Installing $m..." -ForegroundColor Green; \
        Install-Module -Name $m -Scope AllUsers -Force -AllowClobber; \
    }

# Create a minimal PowerShell profile with useful defaults
RUN $profileDir = Split-Path -Path $PROFILE -Parent; \
    if (!(Test-Path $profileDir)) { New-Item -ItemType Directory -Path $profileDir -Force | Out-Null }; \
    @'
# PSSymantecSEPM dev profile
$MaximumFunctionCount = 4096

# Pretty prompt showing module source path
function prompt {
    $repo = "$PWD"
    if (Test-Path "$repo/Source/PSSymantecSEPM.psd1") {
        "SEPM [$repo]`n$('>' * ($nestedPromptLevel + 1)) "
    } else {
        "PS $PWD$('>' * ($nestedPromptLevel + 1)) "
    }
}

# Quick helper to build and import the module
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
'@ | Set-Content -Path $PROFILE -Force

# Set working directory (will be overridden by devcontainer mount)
WORKDIR /workspace

# Default to a login shell so the profile loads
CMD [ "pwsh", "-Login" ]
