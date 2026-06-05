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

# Copy PowerShell profile (must come before SHELL switch for COPY to work)
COPY .devcontainer/profile.ps1 /root/.config/powershell/Microsoft.PowerShell_profile.ps1

# Install Python + pywinrm for WinRM/PS 5.1 testing
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/* \
    && pip3 install --user pywinrm

# Switch to PowerShell for module installation
SHELL ["/usr/bin/pwsh", "-c"]

# Install required PowerShell modules for development
RUN $ErrorActionPreference = 'Stop'; \
    $modules = @( \
        'ModuleBuilder', \
        'Configuration', \
        @{ Name = 'Pester'; RequiredVersion = '5.7.1' }, \
        'PSScriptAnalyzer', \
        'PlatyPS' \
    ); \
    foreach ($m in $modules) { \
        if ($m -is [hashtable]) { \
            Write-Host "Installing $($m.Name) $($m.RequiredVersion)..." -ForegroundColor Green; \
            Install-Module -Name $m.Name -RequiredVersion $m.RequiredVersion -Scope AllUsers -Force -AllowClobber; \
        } else { \
            Write-Host "Installing $m..." -ForegroundColor Green; \
            Install-Module -Name $m -Scope AllUsers -Force -AllowClobber; \
        } \
    }

# Set working directory (will be overridden by devcontainer mount)
WORKDIR /workspace

# Default to a login shell so the profile loads
CMD [ "pwsh", "-Login" ]
