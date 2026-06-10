function Send-SEPMCommand {
    <#
    .SYNOPSIS
        Sends a command to SEP endpoints through the command queue.
    .DESCRIPTION
        Sends a command to SEP endpoints through the command queue.
        Supports ActiveScan, FullScan, Quarantine, UpdateContent, GetFile,
        and ClearIronCache via -ComputerName or -GroupName.
    .PARAMETER Type
        The type of command to send (ActiveScan, FullScan, Quarantine, UpdateContent,
        GetFile, ClearIronCache).
    .PARAMETER ComputerName
        The name of the computer(s) to send the command to.
    .PARAMETER GroupName
        The full path name of the group to send the command to (e.g. "My Company\Workstations").
    .PARAMETER Undo
        When used with -Type Quarantine, unquarantines the endpoint instead of quarantining.
    .PARAMETER FilePath
        The file path to retrieve. Only valid with -Type GetFile.
    .PARAMETER SHA256
        SHA256 hash (64 hex characters). Valid with -Type GetFile and -Type ClearIronCache.
    .PARAMETER MD5
        MD5 hash (32 hex characters). Valid with -Type GetFile and -Type ClearIronCache.
    .PARAMETER SHA1
        SHA1 hash (40 hex characters). Valid with -Type GetFile and -Type ClearIronCache.
    .PARAMETER Source
        File source location (FILESYSTEM, QUARANTINE, BOTH). Only valid with -Type GetFile.
    .EXAMPLE
        Send-SEPMCommand -Type ActiveScan -ComputerName "PC1"
    .EXAMPLE
        Send-SEPMCommand -Type Quarantine -ComputerName "PC1" -Undo
    .EXAMPLE
        Send-SEPMCommand -Type GetFile -ComputerName "PC1" -SHA256 <64-char-hash> -FilePath "C:\Temp\malware.exe"
    .EXAMPLE
        Send-SEPMCommand -Type ClearIronCache -ComputerName "PC1" -SHA256 <64-char-hash>
    #>

    [CmdletBinding(DefaultParameterSetName = 'ComputerName')]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet('ActiveScan', 'FullScan', 'Quarantine', 'UpdateContent', 'GetFile', 'ClearIronCache')]
        [string]$Type,

        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'ComputerName'
        )]
        [Alias("Hostname", "DeviceName", "Device", "Computer")]
        [string[]]$ComputerName,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = 'GroupName'
        )]
        [string]$GroupName,

        [Parameter()]
        [switch]$Undo,

        [Parameter()]
        [string]$FilePath,

        [Parameter()]
        [string]$SHA256,

        [Parameter()]
        [string]$MD5,

        [Parameter()]
        [string]$SHA1,

        [Parameter()]
        [string]$Source
    )

    begin {
        $session = Initialize-SEPMSession
        $accumulatedComputerNames = @()

        $hashParamSpecs = @{
            SHA256 = @{ Length = 64; HashType = 'sha256' }
            MD5    = @{ Length = 32; HashType = 'md5' }
            SHA1   = @{ Length = 40; HashType = 'sha1' }
        }

        $commandRegistry = @{
            ActiveScan     = @{ Path = 'activescan' }
            FullScan       = @{ Path = 'fullscan' }
            Quarantine     = @{ Path = 'quarantine'; Params = @{ Undo = @{ Key = 'undo' } } }
            UpdateContent  = @{ Path = 'updatecontent' }
            GetFile        = @{ Path = 'files'; Params = @{
                FilePath = @{ Key = 'file_path' }
                SHA256   = @{ Key = 'sha256' } + $hashParamSpecs.SHA256
                MD5      = @{ Key = 'md5' } + $hashParamSpecs.MD5
                SHA1     = @{ Key = 'sha1' } + $hashParamSpecs.SHA1
                Source   = @{ Key = 'source'; ValidateSet = @('FILESYSTEM', 'QUARANTINE', 'BOTH') }
            }}
            ClearIronCache  = @{ Path = 'ironcache'; Params = $hashParamSpecs; Body = {
                param($HashType, $HashValue)
                @{ hashType = $HashType; data = @($HashValue) }
            }}
        }
    }

    process {
        if ($PSCmdlet.ParameterSetName -eq 'ComputerName') {
            $accumulatedComputerNames += $ComputerName
        }
    }

    end {
        if ($PSCmdlet.ParameterSetName -eq 'ComputerName') {
            $targets = Resolve-SepmCommandTarget -ComputerName $accumulatedComputerNames
        } else {
            $targets = Resolve-SepmCommandTarget -GroupName $GroupName
        }

        $queryStrings = @{}
        if ($targets.computer_ids.Count -gt 0) {
            $queryStrings.computer_ids = $targets.computer_ids
        }
        if ($targets.group_ids.Count -gt 0) {
            $queryStrings.group_ids = $targets.group_ids
        }

        $commandEntry = $commandRegistry[$Type]

        $commonParams = @('ErrorAction', 'WarningAction', 'Verbose', 'Debug', 'ErrorVariable', 'WarningVariable', 'OutVariable', 'OutBuffer', 'PipelineVariable', 'InformationAction', 'InformationVariable', 'ProgressAction')
        $alwaysValid = @('Type', 'ComputerName', 'GroupName') + $commonParams
        $allowedParamNames = if ($commandEntry.ContainsKey('Params')) { $commandEntry.Params.Keys } else { @() }
        foreach ($boundParam in $PSBoundParameters.Keys) {
            if ($boundParam -in $alwaysValid) { continue }
            if ($boundParam -notin $allowedParamNames) {
                $validTypes = foreach ($entryName in ($commandRegistry.Keys | Sort-Object)) {
                    if ($commandRegistry[$entryName].ContainsKey('Params') -and $commandRegistry[$entryName].Params.ContainsKey($boundParam)) {
                        $entryName
                    }
                }
                $validTypesStr = $validTypes -join ', '
                throw "-$boundParam is only valid with -Type $validTypesStr"
            }
        }

        $body = $null

        if ($commandEntry.ContainsKey('Params')) {
            foreach ($paramName in $commandEntry.Params.Keys) {
                if ($PSBoundParameters.ContainsKey($paramName)) {
                    $paramMeta = $commandEntry.Params[$paramName]
                    $paramValue = $PSBoundParameters[$paramName]

                    if ($paramMeta.ContainsKey('Length')) {
                        if ($paramValue.Length -ne $paramMeta.Length) {
                            throw "-$paramName must be exactly $($paramMeta.Length) characters, got $($paramValue.Length)"
                        }
                    }

                    if ($paramMeta.ContainsKey('ValidateSet')) {
                        if ($paramValue -notin $paramMeta.ValidateSet) {
                            throw "-$paramName must be one of: $($paramMeta.ValidateSet -join ', ')"
                        }
                    }

                    if ($paramMeta.ContainsKey('Key')) {
                        $queryStrings[$paramMeta.Key] = $paramValue
                    }
                }
            }
        }

        if ($commandEntry.ContainsKey('Body')) {
            foreach ($paramName in $commandEntry.Params.Keys) {
                if ($PSBoundParameters.ContainsKey($paramName)) {
                    $hashType = $commandEntry.Params[$paramName].HashType
                    $hashValue = $PSBoundParameters[$paramName]
                    $body = ConvertTo-SEPMJson -InputObject (& $commandEntry.Body $hashType $hashValue) -Compress
                    break
                }
            }
        }

        $URI = $session.BaseURLv1 + '/command-queue/' + $commandEntry.Path
        $URI = Build-SEPMQueryURI -BaseURI $URI -QueryStrings $queryStrings

        $apiParams = @{
            Method  = 'POST'
            Uri     = $URI
            Session = $session
        }
        if ($body) { $apiParams.Body = $body }

        $resp = Invoke-SepmApi @apiParams

        Write-Output $resp -NoEnumerate
    }
}
