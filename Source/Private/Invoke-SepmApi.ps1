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

        A failed request is raised as a structured Transport Error, never returned as a
        value. ConvertTo-SEPMTransportError builds the ErrorRecord, so both PS branches
        report the same ErrorId, ErrorCategory and message.

        The value returned on success is a [hashtable], or a string for endpoints whose
        payload is not JSON (the XML policy and location endpoints). A string return
        therefore always means success.

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

    .OUTPUTS
        System.Collections.Hashtable, or System.String for a non-JSON payload.

    .NOTES
        Internal helper method. Not exported. Throws a Transport Error on any failure.
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
            # A failure is a failure, not a value. The HTTP status is only available on
            # the response object; a connection or TLS failure has none, so it stays 0.
            $statusCode = 0
            if ($_.Exception.Response) {
                $statusCode = [int]$_.Exception.Response.StatusCode
            }
            $PSCmdlet.ThrowTerminatingError((ConvertTo-SEPMTransportError `
                        -Exception $_.Exception -Method $Method -Uri $Uri `
                        -StatusCode $statusCode -Body $_.ErrorDetails.Message))
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
    # One try around the whole exchange: a TLS handshake fails while the body is being
    # written (GetRequestStream) just as easily as at GetResponse, so there is no single
    # call to guard. Every failure is raised as a structured Transport Error here, never
    # returned as a value.
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

        $httpResp = $req.GetResponse()

        $respStream = $httpResp.GetResponseStream()
        $respReader = New-Object System.IO.StreamReader($respStream)
        $respBodyStr = $respReader.ReadToEnd()
        $respReader.Close()
        $httpResp.Close()
    } catch {
        # Unwrap to the real exception. PowerShell wraps a failed GetRequestStream (but not
        # GetResponse) in a MethodInvocationException, which carries neither the WebException
        # response nor the AuthenticationException that identifies a certificate failure.
        $failure = $_.Exception
        while ($null -ne $failure -and $failure -is [System.Management.Automation.MethodInvocationException]) {
            $failure = $failure.InnerException
        }

        # SEPM's error body is only readable while the WebException is being handled - the
        # response stream is disposed afterwards - so it is read here and handed to the
        # shared error builder. A connection or TLS failure has no response at all.
        $statusCode = 0
        $errBody = $null
        if ($failure -is [System.Net.WebException] -and $null -ne $failure.Response) {
            $statusCode = [int]$failure.Response.StatusCode
            $errStream = $failure.Response.GetResponseStream()
            $errReader = New-Object System.IO.StreamReader($errStream)
            $errBody = $errReader.ReadToEnd()
            $errReader.Close()
            $failure.Response.Close()
        }

        $PSCmdlet.ThrowTerminatingError((ConvertTo-SEPMTransportError `
                    -Exception $failure -Method $Method -Uri $Uri `
                    -StatusCode $statusCode -Body $errBody))
    }

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
}
