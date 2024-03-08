FROM mcr.microsoft.com/powershell:latest as build
RUN apt-get update && \
    apt-get -y install git

# Clone the repo
WORKDIR /workspace
RUN git clone https://github.com/Douda/PSSymantecSEPM

# Switch to Powershell Shell
SHELL ["/usr/bin/pwsh", "-c"]

# Install Powershell Modules
RUN $ErrorActionPreference='Stop'; Install-Module -Name Pester, InvokeBuild, ModuleBuilder, PlatyPS, PSScriptAnalyzer, PSReadLine -Force

# Import custom Powershell profile
# https://api.github.com/gists/6fcbb253abcfec1df62bfc38667738f7
RUN $ErrorActionPreference='Stop';if (!(Test-Path -Path $PROFILE)) { New-Item -ItemType File -Path $PROFILE -Force }; $gist = Invoke-RestMethod "https://api.github.com/gists/6fcbb253abcfec1df62bfc38667738f7" -ErrorAction Stop; $gistProfile = $gist.Files.'profile.ps1'.Content; Set-Content -Path $profile.CurrentUserAllHosts -Value $gistProfile

# Set the working directory to the cloned repo
WORKDIR /workspace/PSSymantecSEPM

CMD [ "pwsh" ]