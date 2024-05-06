FROM mcr.microsoft.com/powershell:latest as build
RUN apt-get update && \
    apt-get -y install git && \
    apt-get install wget

# Clone the repo
WORKDIR /workspace
RUN git clone -b develop https://github.com/Douda/PSSymantecSEPM

# GitVersion
WORKDIR /tmp
RUN wget https://github.com/GitTools/GitVersion/releases/download/5.12.0/gitversion-linux-x64-5.12.0.tar.gz
RUN tar -xvf gitversion-linux-x64-5.12.0.tar.gz
RUN mv gitversion /usr/local/bin
RUN chmod +x /usr/local/bin/gitversion
RUN rm -rf /tmp/*

# Switch to Powershell Shell
SHELL ["/usr/bin/pwsh", "-c"]

# Install Powershell Modules
RUN $ErrorActionPreference='Stop'; Install-Module -Name Pester, InvokeBuild,  ModuleBuilder, PlatyPS, PSScriptAnalyzer, PSReadLine -Force

# Import custom Powershell profile
# https://api.github.com/gists/6fcbb253abcfec1df62bfc38667738f7
RUN $ErrorActionPreference='Stop';if (!(Test-Path -Path $PROFILE)) { New-Item -ItemType File -Path $PROFILE -Force }; $gist = Invoke-RestMethod "https://api.github.com/gists/6fcbb253abcfec1df62bfc38667738f7" -ErrorAction Stop; $gistProfile = $gist.Files.'profile.ps1'.Content; Set-Content -Path $profile.CurrentUserAllHosts -Value $gistProfile

# Set the working directory to the cloned repo
WORKDIR /workspace/PSSymantecSEPM

CMD [ "pwsh" ]