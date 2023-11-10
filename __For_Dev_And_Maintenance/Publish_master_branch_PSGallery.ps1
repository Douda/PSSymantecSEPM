# Build and load module
# Loading Paths & Variables
. "$PSScriptRoot\Build_and_load_module.ps1"

# Import API Key
$API_PATH = Split-Path $ModuleDevPath -Parent
if (Test-Path "$API_PATH\API_KEY_PS_Gallery.xml") {
    $API_KEY = Import-Clixml -Path "$API_PATH\API_KEY_PS_Gallery.xml" -ErrorAction SilentlyContinue
} else {
    $API_KEY = Read-Host -Prompt 'Enter PS Gallery API Key to publish the module'
}

# Publish Module
$MajorMinorPatch = dotnet-gitversion | ConvertFrom-Json | Select-Object -Expand MajorMinorPatch
Publish-Module -Path "$ModuleDevPath\Output\PSSymantecSEPM\$MajorMinorPatch\" -NuGetApiKey $API_KEY -Verbose
