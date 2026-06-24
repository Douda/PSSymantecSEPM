function Invoke-SepmApi {
    <#
    .SYNOPSIS
        Thin REST wrapper using built-in transports on both PS versions.

    .DESCRIPTION
        PS 7+:  Invoke-RestMethod with optional -SkipCertificateCheck.
                JSON auto-deserialized, converted to [hashtable] for uniform return type.
        PS 5.1: [System.Net.HttpWebRequest] with KeepAlive=false.
                Invoke-RestMethod on .NET Framework 4.x reuses TLS connections
                and SEPM 14.3 rejects them after the first POST ("connection closed").
                KeepAlive=false forces a fresh TLS handshake per request.
                JSON parsed via JavaScriptSerializer, converted to [hashtable].

    .PARAMETER Session
        Session object from Initialize-SEPMSession. Provides Headers and SkipCert.
        Mutually exclusive with -Headers/-SkipCert.

    .PARAMETER Headers
        Hashtable of HTTP headers. For auth bootstrap (Get-SEPMAccessToken).
        Mutually exclusive with -Session.

    .PARAMETER SkipCert
        If true, skip certificate validation. For auth bootstrap (Manual set).

    .PARAMETER Method
        HTTP method (GET, POST, PATCH, etc.)

    .PARAMETER Uri
        Full URI for the request.

    .PARAMETER Body
        Optional request body (string, already serialized).

    .PARAMETER ContentType
        Content-Type header value (defaults to application/json when Body present).
    #>

    [CmdletBinding(DefaultParameterSetName = 'Session')]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'Session')]
        [PSCustomObject]$Session,

        [Parameter(Mandatory = $true, ParameterSetName = 'Manual')]
        [hashtable]$Headers,

        [Parameter(Mandatory = $true, ParameterSetName = 'Manual')]
        [bool]$SkipCert,

        [Parameter(Mandatory = $true)]
        [string]$Method,

        [Parameter(Mandatory = $true)]
        [string]$Uri,

        [string]$Body,

        [string]$ContentType
    )

    # === Resolve effective Headers and SkipCert from parameter set ===
    $effectiveSkipCert = $false
    $effectiveHeaders = @{}

    if ($PSCmdlet.ParameterSetName -eq 'Session') {
        # Validate session object
        if ($null -eq $Session.Headers) {
            throw 'Session object is missing the Headers property. Use Initialize-SEPMSession to create a valid session.'
        }
        if ($null -eq $Session.SkipCert) {
            throw 'Session object is missing the SkipCert property. Use Initialize-SEPMSession to create a valid session.'
        }
        $effectiveSkipCert = $Session.SkipCert
        $effectiveHeaders = $Session.Headers.Clone()
    } else {
        $effectiveSkipCert = $SkipCert
        $effectiveHeaders = $Headers.Clone()
    }

    # === Emit verbose message ===
    Write-Verbose "Invoke-SepmApi: $Method $Uri"

    # === PS 7+ path: Invoke-RestMethod ===
    if ($PSVersionTable.PSVersion.Major -ge 6) {
        $irmParams = @{
            Method  = $Method
            Uri     = $Uri
            Headers = $effectiveHeaders
        }
        if ($Body) { $irmParams.Body = $Body }
        if ($ContentType) { $irmParams.ContentType = $ContentType }

        try {
            if ($effectiveSkipCert) {
                $resp = Invoke-RestMethod @irmParams -SkipCertificateCheck
            } else {
                $resp = Invoke-RestMethod @irmParams
            }
        } catch {
            Write-Warning "Invoke-RestMethod error: $_"
            return "Error: $_"
        }

        # Convert JSON string to [hashtable] for uniform return type
        if ($resp -is [string] -and $resp -match '^\s*[\[\{]') {
            try {
                return $resp | ConvertFrom-Json -AsHashtable -Depth 100 -ErrorAction Stop
            } catch {
                # PS 5.1: -AsHashtable not available, parse to PSCustomObject first
                Write-Verbose "ConvertFrom-Json -AsHashtable unavailable, using ConvertFrom-Json + ConvertTo-Hashtable"
                $resp = $resp | ConvertFrom-Json
            }
        }
        # Convert to hashtable for uniform return type (handles PSCustomObject, arrays, and scalars)
        $result = ConvertTo-Hashtable -InputObject $resp
        # Arrays need -NoEnumerate to prevent PowerShell unrolling 1-element arrays.
        # Write-Output -NoEnumerate on non-arrays returns List<object> in PS 7.6+ (regression).
        if ($result -is [array]) {
            Write-Output $result -NoEnumerate
        } else {
            $result
        }
        return
    }

    # === PS 5.1 path: HttpWebRequest + KeepAlive=false ===
    try {
        if ($effectiveSkipCert) {
            Skip-Cert
        }

        $req = [System.Net.HttpWebRequest]::Create($Uri)
        $req.Method = $Method
        $req.KeepAlive = $false

        # Set Content-Type
        if ($ContentType) {
            $req.ContentType = $ContentType
        } elseif ($Body) {
            $req.ContentType = 'application/json'
        }

        # Apply headers
        $restricted = @('Content-Type', 'Accept', 'Connection', 'Expect', 'Host', 'Referer', 'User-Agent')
        foreach ($key in $effectiveHeaders.Keys) {
            if ($key -eq 'Authorization') {
                $req.Headers['Authorization'] = $effectiveHeaders[$key]
            } elseif ($key -notin $restricted) {
                $req.Headers.Add($key, $effectiveHeaders[$key])
            }
        }

        # Write body
        if ($Body -and $Method -ne 'GET') {
            $bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($Body)
            $req.ContentLength = $bodyBytes.Length
            $reqStream = $req.GetRequestStream()
            $reqStream.Write($bodyBytes, 0, $bodyBytes.Length)
            $reqStream.Close()
        }

        # Get response
        try {
            $httpResp = $req.GetResponse()
        } catch [System.Net.WebException] {
            $errResp = $_.Exception.Response
            if ($errResp) {
                $errStream = $errResp.GetResponseStream()
                $errReader = New-Object System.IO.StreamReader($errStream)
                $errBody = $errReader.ReadToEnd()
                $errReader.Close()
                $errResp.Close()
                return $errBody
            }
            throw
        }

        $respStream = $httpResp.GetResponseStream()
        $respReader = New-Object System.IO.StreamReader($respStream)
        $respBodyStr = $respReader.ReadToEnd()
        $respReader.Close()
        $httpResp.Close()

        # Parse JSON to [hashtable] (uniform return type, no Dictionary→PSObject conversion)
        if ($respBodyStr -match '^\s*[\[\{]') {
            try {
                Add-Type -AssemblyName System.Web.Extensions -ErrorAction SilentlyContinue
                $jss = New-Object System.Web.Script.Serialization.JavaScriptSerializer
                $jss.MaxJsonLength = [int]::MaxValue
                $jss.RecursionLimit = 100
                $parsed = $jss.DeserializeObject($respBodyStr)
                return ConvertTo-Hashtable -InputObject $parsed
            } catch {
                return $respBodyStr
            }
        }

        return $respBodyStr
    } catch {
        Write-Warning "HttpWebRequest error: $_"
        return "Error: $_"
    }
}
