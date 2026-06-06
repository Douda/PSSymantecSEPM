function Invoke-SepmApi {
    <#
    .SYNOPSIS
        Thin REST wrapper using built-in transports on both PS versions.
        Replaces Invoke-ABRestMethod one caller at a time.

    .DESCRIPTION
        PS 7+:  Invoke-RestMethod with optional -SkipCertificateCheck.
                JSON auto-deserialized, or -AsHashtable for case-duplicate-key responses.
        PS 5.1: [System.Net.HttpWebRequest] with KeepAlive=false.
                Invoke-RestMethod on .NET Framework 4.x reuses TLS connections
                and SEPM 14.3 rejects them after the first POST ("connection closed").
                KeepAlive=false forces a fresh TLS handshake per request.
                JSON parsed via JavaScriptSerializer (ConvertFrom-Json chokes on
                case-insensitive duplicate keys like sonar/SONAR in SEPM responses).

    .PARAMETER Method
        HTTP method (GET, POST, PATCH, etc.)
    .PARAMETER Uri
        Full URI for the request.
    .PARAMETER Body
        Optional request body (string, already serialized).
    .PARAMETER Headers
        Hashtable of HTTP headers.
    .PARAMETER ContentType
        Content-Type header value (defaults to application/json when Body present).
    .PARAMETER SkipCert
        If true, skip certificate validation.
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Method,

        [Parameter(Mandatory = $true)]
        [string]$Uri,

        [string]$Body,

        [hashtable]$Headers = @{},

        [string]$ContentType,

        [bool]$SkipCert = $false
    )

    # === PS 7+ path: Invoke-RestMethod ===
    if ($PSVersionTable.PSVersion.Major -ge 6) {
        $irmParams = @{
            Method  = $Method
            Uri     = $Uri
            Headers = $Headers
        }
        if ($Body) { $irmParams.Body = $Body }
        if ($ContentType) { $irmParams.ContentType = $ContentType }

        try {
            if ($SkipCert) {
                $resp = Invoke-RestMethod @irmParams -SkipCertificateCheck
            } else {
                $resp = Invoke-RestMethod @irmParams
            }
        } catch {
            Write-Warning "Invoke-RestMethod error: $_"
            return "Error: $_"
        }

        # SEPM policy responses contain case-insensitive duplicate keys
        # (e.g., "sonar" and "SONAR"). PowerShell ConvertFrom-Json rejects
        # these. Use -AsHashtable which is case-insensitive for keys.
        if ($resp -is [string] -and $resp -match '^\s*[\[\{]') {
            try {
                return $resp | ConvertFrom-Json -AsHashtable -Depth 100 -ErrorAction Stop
            } catch {
                Write-Warning "ConvertFrom-Json -AsHashtable failed: $_"
                return $resp
            }
        }
        return $resp
    }

    # === PS 5.1 path: HttpWebRequest + KeepAlive=false ===
    # Invoke-RestMethod in .NET Framework 4.x reuses TCP connections.
    # SEPM 14.3 rejects reused TLS sessions after the first POST request.
    # HttpWebRequest with KeepAlive=false avoids this entirely.
    # Additionally, ConvertFrom-Json in PS 5.1 fails on case-insensitive
    # duplicate keys (sonar/SONAR). JavaScriptSerializer handles these.

    try {
        if ($SkipCert) {
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
        foreach ($key in $Headers.Keys) {
            if ($key -eq 'Authorization') {
                $req.Headers['Authorization'] = $Headers[$key]
            } elseif ($key -notin $restricted) {
                $req.Headers.Add($key, $Headers[$key])
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

        # Parse JSON
        if ($respBodyStr -match '^\s*[\[\{]') {
            try {
                Add-Type -AssemblyName System.Web.Extensions -ErrorAction SilentlyContinue
                $jss = New-Object System.Web.Script.Serialization.JavaScriptSerializer
                $jss.MaxJsonLength = [int]::MaxValue
                $jss.RecursionLimit = 100
                $parsed = $jss.DeserializeObject($respBodyStr)
                return ConvertFrom-DictionaryToPSObject $parsed
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
