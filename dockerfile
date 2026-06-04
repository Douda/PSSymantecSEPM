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

# Set working directory (will be overridden by devcontainer mount)
WORKDIR /workspace

# Default to a login shell so the profile loads
CMD [ "pwsh", "-Login" ]
