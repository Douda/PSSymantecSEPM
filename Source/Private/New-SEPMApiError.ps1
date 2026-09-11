function New-SEPMApiError {
    <#
    .SYNOPSIS
        Builds the ErrorRecord the transport throws for a failed SEPM request.

    .DESCRIPTION
        Every failure the REST transport reports is raised through this helper so the
        ErrorId, ErrorCategory and target stay consistent across the PS 7 and PS 5.1
        code paths.

        ErrorId defaults to SEPM.ApiError, which covers every server-side refusal and
        every unreachable server. Callers pass an explicit id only for the two cases
        that map to a different remedy:
            SEPM.AuthenticationFailed  the credential was rejected  -> re-authenticate
            SEPM.CertificateError      TLS validation failed        -> trust the certificate

        The ErrorCategory refines the id (InvalidData, ObjectNotFound, PermissionDenied,
        ResourceUnavailable, ConnectionError, ...). ConvertTo-SEPMTransportError decides it.

        Note: PowerShell composes FullyQualifiedErrorId as '<ErrorId>,<ExceptionTypeName>',
        so callers match on it with -like 'SEPM.ApiError*' rather than -eq.

    .PARAMETER Message
        The complete, user-facing error message.

    .PARAMETER ErrorId
        SEPM.ApiError (default), SEPM.AuthenticationFailed, or SEPM.CertificateError.

    .PARAMETER Category
        The ErrorCategory refining the failure. Defaults to ConnectionError.

    .PARAMETER Target
        The object the failure relates to - the request URI in practice.

    .OUTPUTS
        System.Management.Automation.ErrorRecord

    .NOTES
        Internal helper method. Not exported.
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.ErrorRecord])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [string]$ErrorId = 'SEPM.ApiError',

        [System.Management.Automation.ErrorCategory]$Category = [System.Management.Automation.ErrorCategory]::ConnectionError,

        [object]$Target
    )

    return [System.Management.Automation.ErrorRecord]::new(
        [System.Exception]::new($Message),
        $ErrorId,
        $Category,
        $Target
    )
}
