function Send-SEPMCommand {
    <#
    .SYNOPSIS
        Sends a command to SEP endpoints through the command queue.
    .DESCRIPTION
        Sends a command to SEP endpoints through the command queue.
        Supports ActiveScan, FullScan, Quarantine, UpdateContent, GetFile,
        and ClearIronCache via -ComputerName.
    .PARAMETER Type
        The type of command to send (ActiveScan, FullScan, Quarantine, UpdateContent,
        GetFile, ClearIronCache).
    .PARAMETER ComputerName
        The name of the computer(s) to send the command to.
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

    [CmdletBinding()]
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

        $commandRegistry = @{
            ActiveScan     = @{ Path = 'activescan' }
            FullScan       = @{ Path = 'fullscan' }
            Quarantine     = @{ Path = 'quarantine'; Params = @{ Undo = @{ Key = 'undo' } } }
            UpdateContent  = @{ Path = 'updatecontent' }
            GetFile        = @{ Path = 'files'; Params = @{
                FilePath = @{ Key = 'file_path'; Required = $true }
                SHA256   = @{ Key = 'sha256'; Length = 64 }
                MD5      = @{ Key = 'md5'; Length = 32 }
                SHA1     = @{ Key = 'sha1'; Length = 40 }
                Source   = @{ Key = 'source'; ValidateSet = @('FILESYSTEM', 'QUARANTINE', 'BOTH') }
            }}
            ClearIronCache  = @{ Path = 'ironcache'; Params = @{
                SHA256 = @{ Length = 64 }
                MD5    = @{ Length = 32 }
                SHA1   = @{ Length = 40 }
            }; Body = {
                param($HashType, $HashValue)
                @{ hashType = $HashType; data = @($HashValue) }
            }}
        }
    }

    process {
        $targets = Resolve-SepmCommandTarget -ComputerName $ComputerName

        $queryStrings = @{
            computer_ids = $targets.computer_ids
        }

        $commandEntry = $commandRegistry[$Type]

        # Validate: every bound param must be allowed for this command type
        $commonParams = @('ErrorAction', 'WarningAction', 'Verbose', 'Debug', 'ErrorVariable', 'WarningVariable', 'OutVariable', 'OutBuffer', 'PipelineVariable', 'InformationAction', 'InformationVariable', 'ProgressAction')
        $alwaysValid = @('Type', 'ComputerName') + $commonParams
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

        # Serialize params to query strings (for types without Body) or JSON body
        $body = $null
        $queryParamKeys = @{}

        if ($commandEntry.ContainsKey('Params')) {
            foreach ($paramName in $commandEntry.Params.Keys) {
                if ($PSBoundParameters.ContainsKey($paramName)) {
                    $paramMeta = $commandEntry.Params[$paramName]
                    $paramValue = $PSBoundParameters[$paramName]

                    # Validate length constraint
                    if ($paramMeta.ContainsKey('Length')) {
                        if ($paramValue.Length -ne $paramMeta.Length) {
                            throw "-$paramName must be exactly $($paramMeta.Length) characters, got $($paramValue.Length)"
                        }
                    }

                    # Validate ValidateSet constraint
                    if ($paramMeta.ContainsKey('ValidateSet')) {
                        if ($paramValue -notin $paramMeta.ValidateSet) {
                            throw "-$paramName must be one of: $($paramMeta.ValidateSet -join ', ')"
                        }
                    }

                    # Route to query params or body
                    if ($paramMeta.ContainsKey('Key')) {
                        $queryParamKeys[$paramMeta.Key] = $paramValue
                    }
                }
            }
        }

        # Build body from Body scriptblock (ClearIronCache)
        if ($commandEntry.ContainsKey('Body')) {
            $hashType = $null
            $hashValue = $null
            if ($PSBoundParameters.ContainsKey('SHA256')) { $hashType = 'sha256'; $hashValue = $PSBoundParameters['SHA256'] }
            elseif ($PSBoundParameters.ContainsKey('MD5')) { $hashType = 'md5'; $hashValue = $PSBoundParameters['MD5'] }
            elseif ($PSBoundParameters.ContainsKey('SHA1')) { $hashType = 'sha1'; $hashValue = $PSBoundParameters['SHA1'] }
            $bodyHashtable = & $commandEntry.Body $hashType $hashValue
            $body = ConvertTo-SEPMJson -InputObject $bodyHashtable -Compress
        }

        # Merge query params: computer_ids + command-specific params
        foreach ($key in $queryParamKeys.Keys) {
            $queryStrings[$key] = $queryParamKeys[$key]
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
