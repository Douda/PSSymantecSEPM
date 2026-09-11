function ConvertTo-SEPMTransportError {
    <#
    .SYNOPSIS
        Turns a failed SEPM REST request into a structured Transport Error.

    .DESCRIPTION
        The single place that interprets a transport failure. Both the PS 7 and the
        PS 5.1 branch of Invoke-SepmApi funnel their exceptions through here, so the
        ErrorId, ErrorCategory and message are identical on both PowerShell versions.

        SEPM reports failures in three different body shapes:
            {"errorCode":"400","appErrorCode":"","errorMessage":"..."}   application error
            {"error":"invalid_token","error_description":"..."}          authentication error
            <!doctype html>...                                          servlet container error

        SEPM's HTTP status does not always match the error it reports - a bad argument
        comes back as HTTP 500 with errorCode 400 in the body. The body's errorCode is
        therefore preferred when choosing the ErrorCategory, with the HTTP status as the
        fallback, so a bad argument is not mislabelled as a server fault.

        A certificate failure never reaches the API; it fails during the TLS handshake.
        It is detected by walking the exception chain for
        System.Security.Authentication.AuthenticationException, because the .NET message
        text is localized and cannot be matched reliably on a non-English Windows.

    .PARAMETER Exception
        The exception the transport caught.

    .PARAMETER Method
        The HTTP method of the failed request.

    .PARAMETER Uri
        The full URI of the failed request. Only its path and query appear in the
        message; the full URI is attached as the ErrorRecord target.

    .PARAMETER StatusCode
        The HTTP status code, or 0 when the request never received a response.

    .PARAMETER Body
        The raw error body, when one was readable.

    .OUTPUTS
        System.Management.Automation.ErrorRecord

    .NOTES
        Internal helper method. Not exported.
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.ErrorRecord])]
    param(
        [Parameter(Mandatory = $true)]
        [System.Exception]$Exception,

        [Parameter(Mandatory = $true)]
        [string]$Method,

        [Parameter(Mandatory = $true)]
        [string]$Uri,

        [int]$StatusCode = 0,

        [string]$Body
    )

    # The path and query identify the failure; the host is already known from
    # configuration, so it is left out of the message.
    $path = $Uri
    try {
        $uriObject = [System.Uri]::new($Uri)
        $path = $uriObject.PathAndQuery
    } catch {
        # Not a parseable URI - fall back to the raw string.
    }

    # === Certificate failure: detected before looking at any body ===
    $certificateException = $null
    $exceptionCursor = $Exception
    while ($null -ne $exceptionCursor) {
        if ($exceptionCursor -is [System.Security.Authentication.AuthenticationException]) {
            $certificateException = $exceptionCursor
            break
        }
        $exceptionCursor = $exceptionCursor.InnerException
    }

    # Locale-independent fallback. The type walk above is the reliable signal, so this
    # only catches an exception that wraps the failure in an unexpected way.
    $isCertificateError = ($null -ne $certificateException)
    if (-not $isCertificateError -and $Exception.Message -match 'certificate') {
        $isCertificateError = $true
    }

    if ($isCertificateError) {
        # Prefer the innermost message: it is the specific one ("The remote certificate is
        # invalid according to the validation procedure: RemoteCertificateNameMismatch...").
        # The outermost is usually just "The SSL connection could not be established".
        $detail = $Exception.Message
        if ($null -ne $certificateException) {
            $detail = $certificateException.Message
        }

        $message = "SEPM API $Method $path failed: the TLS certificate could not be validated ($detail)."
        return (New-SEPMApiError -Message $message -ErrorId 'SEPM.CertificateError' `
                -Category ([System.Management.Automation.ErrorCategory]::SecurityError) -Target $Uri)
    }

    # === SEPM's own error body ===
    $sepmCode = 0
    $detail = $null

    if (-not [string]::IsNullOrWhiteSpace($Body)) {
        $parsedBody = $null
        try {
            $parsedBody = $Body | ConvertFrom-Json -ErrorAction Stop
        } catch {
            # Not JSON: an HTML error page, or truncated text.
            $parsedBody = $null
        }

        if ($null -ne $parsedBody -and $parsedBody -is [PSCustomObject]) {
            if ($null -ne $parsedBody.errorCode) {
                # Shape 1: application error.
                $sepmCode = [int]($parsedBody.errorCode -as [int])
                $detail = $parsedBody.errorMessage
            } elseif (-not [string]::IsNullOrWhiteSpace($parsedBody.error_description)) {
                # Shape 2: authentication error.
                $detail = $parsedBody.error_description
            } elseif (-not [string]::IsNullOrWhiteSpace($parsedBody.error)) {
                $detail = $parsedBody.error
            }
        }

        if ([string]::IsNullOrWhiteSpace($detail)) {
            # Shape 3: HTML or plain text. A SEPM 404 comes back as a servlet-container
            # error page. PS 5.1 hands over the raw markup; PS 7 has already stripped the
            # tags, so strip what is still there before deciding what the page is.
            $flat = $Body
            if ($flat -match '(?is)<\s*(html|head|body|title|style)\b') {
                $flat = $flat -replace '(?is)<(script|style)\b.*?</\1>', ' '
                $flat = $flat -replace '(?s)<[^>]+>', ' '
            }
            $flat = ($flat -replace '\s+', ' ').Trim()

            # The error page carries nothing beyond the HTTP status the message already
            # reports, and its inline CSS would otherwise fill the whole message. Say what
            # it is instead of pasting it.
            if ($flat -match 'HTTP Status \d{3}' -or $flat -match 'Status Report') {
                $detail = 'the server returned an HTML error page'
            } else {
                $detail = $flat
                if ($detail.Length -gt 400) {
                    $detail = $detail.Substring(0, 400) + '... (truncated)'
                }
            }
        }
    }

    # === Category: SEPM's own code first, HTTP status as fallback ===
    # SEPM answers a bad argument with HTTP 500 and errorCode 400 in the body. Trusting
    # the HTTP status would label that a server fault; the body code says InvalidData.
    $effectiveCode = $StatusCode
    if ($sepmCode -gt 0) { $effectiveCode = $sepmCode }

    $category = [System.Management.Automation.ErrorCategory]::NotSpecified
    switch ($effectiveCode) {
        400 { $category = [System.Management.Automation.ErrorCategory]::InvalidData }
        401 { $category = [System.Management.Automation.ErrorCategory]::AuthenticationError }
        403 { $category = [System.Management.Automation.ErrorCategory]::PermissionDenied }
        404 { $category = [System.Management.Automation.ErrorCategory]::ObjectNotFound }
        422 { $category = [System.Management.Automation.ErrorCategory]::InvalidData }
        429 { $category = [System.Management.Automation.ErrorCategory]::LimitsExceeded }
        default {
            if ($effectiveCode -ge 500) {
                $category = [System.Management.Automation.ErrorCategory]::ResourceUnavailable
            } elseif ($effectiveCode -eq 0) {
                # No response at all: connection refused, DNS failure, timeout.
                $category = [System.Management.Automation.ErrorCategory]::ConnectionError
            }
        }
    }

    # A 401 mid-session means the token expired or was revoked. The remedy is the same as
    # for a rejected credential, so it carries the same ErrorId.
    $errorId = 'SEPM.ApiError'
    if ($effectiveCode -eq 401) { $errorId = 'SEPM.AuthenticationFailed' }

    # === Compose the message ===
    $statusPart = ''
    if ($StatusCode -gt 0 -and $sepmCode -gt 0 -and $sepmCode -ne $StatusCode) {
        # The two disagree - show both so the discrepancy is visible rather than hidden.
        $statusPart = " (HTTP $StatusCode, SEPM code $sepmCode)"
    } elseif ($StatusCode -gt 0) {
        $statusPart = " (HTTP $StatusCode)"
    } elseif ($sepmCode -gt 0) {
        $statusPart = " (SEPM code $sepmCode)"
    }

    if ([string]::IsNullOrWhiteSpace($detail)) {
        $message = "SEPM API $Method $path failed${statusPart}: $($Exception.Message)"
    } else {
        $message = "SEPM API $Method $path failed${statusPart}: $detail"
    }

    return (New-SEPMApiError -Message $message -ErrorId $errorId -Category $category -Target $Uri)
}
