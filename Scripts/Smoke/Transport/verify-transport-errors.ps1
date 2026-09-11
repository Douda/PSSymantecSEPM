<#
.SYNOPSIS
    Live check of the SEPM transport error contract, on PS 7 and Windows PowerShell 5.1.

.DESCRIPTION
    Runs the module against a real SEPM and asserts the ErrorId, ErrorCategory and message
    of every way a REST call can fail.

    The unit suite cannot cover this. Tests/Invoke-SepmApi.Tests.ps1 mocks $PSVersionTable
    and Invoke-RestMethod, so the PS 5.1 HttpWebRequest branch never executes - and a live
    run is what found a real defect there: a TLS failure at GetRequestStream escaped the
    transport as a MethodInvocationException, so every POST (authentication included) was
    reported as SEPM.AuthenticationFailed instead of SEPM.CertificateError. See
    docs/adr/0010-transport-throws-structured-errors.md.

    Order matters: Skip-Cert installs a process-wide
    ServicePointManager.ServerCertificateValidationCallback that cannot be unset, so check 1
    must run before anything sets $script:SkipCert = $true.

    The module's config / credential / token files are snapshotted before the run and
    restored afterwards, including the case where they did not exist.

.PARAMETER ModulePath
    Module manifest to import. Defaults to the built module in the repo
    (../../../Output/PSSymantecSEPM/PSSymantecSEPM.psd1) when run from the repository, or
    to ./PSSymantecSEPM/PSSymantecSEPM.psd1 when deployed beside the module.

.PARAMETER ReportPath
    File to write the full log to. Defaults to transport-verify-result.txt in the temp
    directory - point it at the shared volume to read the result from the host.

.PARAMETER ServerAddress
    SEPM host. Use 'localhost' when running inside the VM, and the VM's bridge address
    (172.20.0.2) when running from the devcontainer.

.PARAMETER Port
    SEPM REST API port.

.PARAMETER DeadPort
    A port on ServerAddress with nothing listening, for the unreachable-server check.

.PARAMETER UserName
    SEPM API user.

.PARAMETER Password
    Password for UserName.

.EXAMPLE
    # PS 7, from the devcontainer, against the VM's SEPM
    pwsh -NoProfile -File Scripts/Smoke/Transport/verify-transport-errors.ps1 -ServerAddress 172.20.0.2

.EXAMPLE
    # Windows PowerShell 5.1: deploy the script and the built module to the shared volume,
    # then run it on the VM (see docs/agents/smoke-testing.md)
    cp Scripts/Smoke/Transport/verify-transport-errors.ps1 /home/douda/Windows/
    cp -r ./Output/PSSymantecSEPM /home/douda/Windows/PSSymantecSEPM
    WINRM_HOST=172.20.0.2 WINRM_USER=douda WINRM_PASS=aurelien \
        python3 Scripts/invoke-winrm.py 'C:\Users\douda\Desktop\Shared\verify-transport-errors.ps1'

.OUTPUTS
    Console log, an optional report file, and exit code 1 when any check fails.
#>
[CmdletBinding()]
param(
    [string]$ModulePath,
    [string]$ReportPath,
    [string]$ServerAddress = 'localhost',
    [int]$Port = 8446,
    [int]$DeadPort = 8447,
    [string]$UserName = 'sepm_api',
    [string]$Password = 'Aurelien1!'
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# === resolve defaults ===
if (-not $ModulePath) {
    $candidates = @(
        (Join-Path $PSScriptRoot '../../../Output/PSSymantecSEPM/PSSymantecSEPM.psd1'),
        (Join-Path $PSScriptRoot 'PSSymantecSEPM/PSSymantecSEPM.psd1')
    )
    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) {
            $ModulePath = (Resolve-Path $candidate).Path
            break
        }
    }
    if (-not $ModulePath) {
        throw "No module found. Build it (Build-Module) or pass -ModulePath."
    }
}
if (-not $ReportPath) {
    $ReportPath = Join-Path ([System.IO.Path]::GetTempPath()) 'transport-verify-result.txt'
}

$lines = New-Object System.Collections.ArrayList
function Log([string]$Text) {
    [void]$lines.Add($Text)
    Write-Host $Text
}

$results = @{}
function Assert([string]$Name, [bool]$Ok, [string]$Detail) {
    if ($Ok) { $results[$Name] = 'PASS' } else { $results[$Name] = 'FAIL' }
    $tag = 'FAIL'
    if ($Ok) { $tag = 'PASS' }
    Log ("[{0}] {1}" -f $tag, $Name)
    Log ("        {0}" -f $Detail)
}

# Captures the last thrown error so a check can inspect it instead of exploding.
$script:lastId = $null
$script:lastCat = $null
$script:lastMsg = $null
function Try-Call([scriptblock]$Block) {
    $script:lastId = $null
    $script:lastCat = $null
    $script:lastMsg = $null
    try {
        return (& $Block)
    } catch {
        $script:lastId = ([string]$_.FullyQualifiedErrorId).Split(',')[0]
        $script:lastCat = [string]$_.CategoryInfo.Category
        $script:lastMsg = $_.Exception.Message
        return $null
    }
}

function Describe-LastError {
    return "id=$script:lastId cat=$script:lastCat msg=$script:lastMsg"
}

Log ("PSSymantecSEPM transport verification on PowerShell {0} ({1})" -f $PSVersionTable.PSVersion, $PSVersionTable.PSEdition)
Log ("Module: {0}" -f $ModulePath)
Log ("Target: https://{0}:{1}/sepm/api/v1" -f $ServerAddress, $Port)

$mod = Import-Module $ModulePath -Force -PassThru

# === snapshot the module's on-disk state so the machine is left as found ===
$stateFiles = & $mod { @($script:configurationFilePath, $script:credentialsFilePath, $script:accessTokenFilePath) }
$script:tokenFile = $stateFiles[2]
$backupDir = Join-Path ([System.IO.Path]::GetTempPath()) 'sepm-transport-verify-backup'
if (Test-Path $backupDir) { Remove-Item $backupDir -Recurse -Force }
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
for ($i = 0; $i -lt $stateFiles.Count; $i++) {
    if (Test-Path $stateFiles[$i]) { Copy-Item $stateFiles[$i] (Join-Path $backupDir "state-$i") -Force }
}

$good = [PSCredential]::new($UserName, (ConvertTo-SecureString $Password -AsPlainText -Force))
$bad = [PSCredential]::new($UserName, (ConvertTo-SecureString 'DefinitelyWrong!' -AsPlainText -Force))

function Reset-ModuleState {
    param([bool]$SkipCert = $true)
    & $mod {
        param($skip)
        $script:_session = $null
        $script:accessToken = $null
        $script:SkipCert = $skip
    } $SkipCert
    Remove-Item -Path $script:tokenFile -Force -ErrorAction SilentlyContinue
}

# --- 1. certificate failure. MUST run before Skip-Cert installs its global callback. ---
Log ''
Log '--- 1. untrusted certificate ---'
Set-SEPMConfiguration -ServerAddress $ServerAddress -Port $Port
Reset-ModuleState -SkipCert $false
Set-SEPMAuthentication -Credentials $good
$null = Try-Call { Get-SEPMVersion }
Assert 'untrusted certificate -> SEPM.CertificateError' ($script:lastId -eq 'SEPM.CertificateError') (Describe-LastError)
Assert 'untrusted certificate -> SecurityError category' ($script:lastCat -eq 'SecurityError') (Describe-LastError)

# --- 2. happy path ---
Log ''
Log '--- 2. happy path ---'
Reset-ModuleState -SkipCert $true
$version = Try-Call { Get-SEPMVersion }
$versionText = ''
if ($null -ne $version) { $versionText = [string]$version.version }
Assert 'authenticate + Get-SEPMVersion succeeds' (-not [string]::IsNullOrEmpty($versionText)) "version=$versionText"

# --- 3. 0-byte token cache is discarded, not fatal ---
Log ''
Log '--- 3. 0-byte token cache ---'
& $mod {
    Set-Content -Path $script:accessTokenFilePath -Value '' -NoNewline
    "token cache : $script:accessTokenFilePath ($((Get-Item $script:accessTokenFilePath).Length) bytes)"
} | ForEach-Object { Log ("        {0}" -f $_) }
Reset-ModuleState -SkipCert $true
$version3 = Try-Call { Get-SEPMVersion }
$versionText3 = ''
if ($null -ne $version3) { $versionText3 = [string]$version3.version }
Assert 'recovers from a 0-byte token cache' (-not [string]::IsNullOrEmpty($versionText3)) "version=$versionText3"

# --- 4. wrong password ---
Log ''
Log '--- 4. wrong password ---'
Reset-ModuleState -SkipCert $true
Set-SEPMAuthentication -Credentials $bad
$null = Try-Call { Get-SEPMVersion }
Assert 'wrong password -> SEPM.AuthenticationFailed' ($script:lastId -eq 'SEPM.AuthenticationFailed') (Describe-LastError)
Assert 'wrong password -> AuthenticationError category' ($script:lastCat -eq 'AuthenticationError') (Describe-LastError)

# --- 5. server-side refusal (SEPM error body) ---
Log ''
Log '--- 5. server-side refusal ---'
Reset-ModuleState -SkipCert $true
Set-SEPMAuthentication -Credentials $good
$null = Try-Call { Get-SEPMVersion }
$null = Try-Call { Get-SEPMFileDetails -FileId 'not-a-guid' }
Assert 'bad GUID -> SEPM.ApiError' ($script:lastId -eq 'SEPM.ApiError') (Describe-LastError)
Assert 'bad GUID -> InvalidData category' ($script:lastCat -eq 'InvalidData') (Describe-LastError)

# --- 6. HTML error page from the servlet container ---
Log ''
Log '--- 6. HTML error page ---'
$null = Try-Call {
    & $mod {
        $s = Initialize-SEPMSession
        Invoke-SepmApi -Method GET -Uri "$($s.BaseURLv1)/this-endpoint-does-not-exist" -Session $s
    }
}
$htmlOk = $false
if ($script:lastMsg -like '*HTML error page*') { $htmlOk = $true }
Assert 'HTML error page -> readable message' $htmlOk (Describe-LastError)
Assert 'HTML error page -> ObjectNotFound category' ($script:lastCat -eq 'ObjectNotFound') (Describe-LastError)

# --- 7. no response at all: DNS failure, connection refused, TLS handshake ---
Log ''
Log '--- 7. unreachable server (no WebException.Response) ---'
Reset-ModuleState -SkipCert $true
$deadUrl = "https://${ServerAddress}:${DeadPort}/sepm/api/v1/version"
$null = Try-Call {
    & $mod {
        param($url)
        Invoke-SepmApi -Method GET -Uri $url -Headers @{} -SkipCert $true
    } $deadUrl
}
Assert 'unreachable server -> SEPM.ApiError' ($script:lastId -eq 'SEPM.ApiError') (Describe-LastError)
Assert 'unreachable server -> ConnectionError category' ($script:lastCat -eq 'ConnectionError') (Describe-LastError)

# --- 8. real work resumes after all those failures ---
Log ''
Log '--- 8. recovery ---'
Reset-ModuleState -SkipCert $true
Set-SEPMAuthentication -Credentials $good
$groups = Try-Call { Get-SEPMGroups }
$groupCount = -1
if ($null -ne $groups) { $groupCount = @($groups).Count }
Assert 'paginated read works (Get-SEPMGroups)' ($groupCount -ge 0) "groups=$groupCount"
$version8 = Try-Call { Get-SEPMVersion }
$versionText8 = ''
if ($null -ne $version8) { $versionText8 = [string]$version8.version }
Assert 'module still healthy afterwards' (-not [string]::IsNullOrEmpty($versionText8)) "version=$versionText8"

# === restore module state ===
for ($i = 0; $i -lt $stateFiles.Count; $i++) {
    Remove-Item $stateFiles[$i] -Force -ErrorAction SilentlyContinue
    $saved = Join-Path $backupDir "state-$i"
    if (Test-Path $saved) { Copy-Item $saved $stateFiles[$i] -Force }
}
Remove-Item $backupDir -Recurse -Force -ErrorAction SilentlyContinue

$pass = @($results.Keys | Where-Object { $results[$_] -eq 'PASS' }).Count
$fail = @($results.Keys | Where-Object { $results[$_] -ne 'PASS' }).Count
Log ''
Log '========== Transport error contract =========='
foreach ($key in $results.Keys | Sort-Object) {
    Log ("  {0} : {1}" -f $key, $results[$key])
}
Log ("TOTAL: {0} tests, {1} pass, {2} fail, 0 skip" -f ($pass + $fail), $pass, $fail)

$lines -join "`r`n" | Set-Content -Path $ReportPath -Encoding UTF8
Log ("Report: {0}" -f $ReportPath)

if ($fail -gt 0) { exit 1 }
