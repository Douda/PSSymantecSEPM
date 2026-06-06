function Invoke-ABRestMethod {
    <#
    .SYNOPSIS
        Invokes a REST method with a PS version-appropriate method
    .DESCRIPTION
        Invokes a REST method with a PS version-appropriate method
        Handles the differences between PS versions 5 and 6 for certificate validation skipping
    .NOTES
        Helper function for Invoke-ABRestMethod
    .PARAMETER params
        A hashtable of parameters to pass to the Invoke-RestMethod cmdlet
    .EXAMPLE
        $params = @{
            Method  = 'POST'
            Uri     = $URI
            headers = $headers
        }
        Invoke-ABRestMethod -params $params
    #>
    
    
    param (
        # Hashtable of parameters
        [Parameter(
            Mandatory = $true
        )]
        [hashtable]
        $params
    )

    # If a Session object is provided, use its properties; otherwise fall back to script scope
    if ($params.ContainsKey('Session') -and $params.Session) {
        $effectiveSkipCert = $params.Session.SkipCert
        # Merge Session.Headers into $params.headers (Session.Headers as base)
        $mergedHeaders = @{} + $params.Session.Headers
        if ($params.ContainsKey('headers') -and $params.headers) {
            foreach ($key in $params.headers.Keys) {
                $mergedHeaders[$key] = $params.headers[$key]
            }
        }
        $params.headers = $mergedHeaders
        # Remove Session key to avoid partial-match collision with Invoke-RestMethod -SessionVariable
        $params.Remove('Session')
    } else {
        $effectiveSkipCert = $script:SkipCert
    }

    switch ($PSVersionTable.PSVersion.Major) {
        { $_ -ge 6 } { 
            try {
                if ($effectiveSkipCert -eq $true) {
                    $resp = Invoke-RestMethod @params -SkipCertificateCheck
                } else {
                    $resp = Invoke-RestMethod @params
                }
            } catch {
                Write-Warning -Message "Error: $_"
                return "Error: $_"
            }
        }
        default {
            # PS 5.1: Use HttpWebRequest with KeepAlive=false.
            # Invoke-RestMethod reuses TCP connections in .NET Framework 4.x,
            # and SEPM's TLS implementation rejects reused connections after
            # the first successful POST (all subsequent requests fail with
            # "connection closed"). HttpWebRequest with KeepAlive=false
            # forces a fresh TLS handshake for every call.
            try {
                if ($effectiveSkipCert -eq $true) {
                    Skip-Cert
                }

                $req = [System.Net.HttpWebRequest]::Create($params.Uri)
                $req.Method = if ($params.ContainsKey('Method')) { $params.Method } else { 'GET' }
                $req.KeepAlive = $false
                if ($params.ContainsKey('ContentType')) {
                    $req.ContentType = $params.ContentType
                } elseif ($params.ContainsKey('Body') -and $params.Body) {
                    $req.ContentType = 'application/json'
                }

                # Apply headers (skip restricted headers already set via properties)
                $restricted = @('Content-Type','Accept','Connection','Expect','Host','Referer','User-Agent')
                if ($params.ContainsKey('headers') -and $params.headers) {
                    foreach ($key in $params.headers.Keys) {
                        if ($key -eq 'Authorization') {
                            $req.Headers['Authorization'] = $params.headers[$key]
                        } elseif ($key -notin $restricted) {
                            $req.Headers.Add($key, $params.headers[$key])
                        }
                    }
                }

                # Write body for methods that support it
                if ($params.ContainsKey('Body') -and $params.Body -and $req.Method -ne 'GET') {
                    $bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($params.Body)
                    $req.ContentLength = $bodyBytes.Length
                    $reqStream = $req.GetRequestStream()
                    $reqStream.Write($bodyBytes, 0, $bodyBytes.Length)
                    $reqStream.Close()
                }

                try {
                    $httpResp = $req.GetResponse()
                } catch [System.Net.WebException] {
                    # Read error response body (4xx, 5xx)
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

                # Parse JSON to object (match Invoke-RestMethod behavior)
                if ($respBodyStr -match '^\s*[\[\{]') {
                    try {
                        Add-Type -AssemblyName System.Web.Extensions -ErrorAction SilentlyContinue
                        $jss = New-Object System.Web.Script.Serialization.JavaScriptSerializer
                        $jss.MaxJsonLength = [int]::MaxValue
                        $jss.RecursionLimit = 100
                        $parsed = $jss.DeserializeObject($respBodyStr)
                        $resp = ConvertFrom-DictionaryToPSObject $parsed
                    } catch {
                        $resp = $respBodyStr
                    }
                } else {
                    $resp = $respBodyStr
                }
            } catch {
                Write-Warning -Message "Error: $_"
                return "Error: $_"
            }
        }
    }
    
    # return the response
    return $resp
}

function ConvertFrom-DictionaryToPSObject {
    <#
    .SYNOPSIS
        Recursively converts Dictionary/ArrayList from JavaScriptSerializer to PSCustomObject.
        Used by Invoke-ABRestMethod on PS 5.1 to match Invoke-RestMethod's JSON parsing behavior.
    #>
    param($obj)

    if ($null -eq $obj) { return $null }

    if ($obj -is [System.Collections.IDictionary]) {
        $result = New-Object PSObject
        foreach ($key in $obj.Keys) {
            $val = ConvertFrom-DictionaryToPSObject $obj[$key]
            $result | Add-Member -MemberType NoteProperty -Name $key -Value $val -Force
        }
        return $result
    }

    if ($obj -is [System.Collections.IList] -and $obj -isnot [string]) {
        $arr = @()
        foreach ($item in $obj) {
            $arr += ConvertFrom-DictionaryToPSObject $item
        }
        return $arr
    }

    return $obj
}