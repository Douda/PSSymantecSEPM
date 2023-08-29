function Get-SepmConfiguration {
    <#
    .SYNOPSIS
        Gets the currently configured value for the requested configuration setting.

    .DESCRIPTION
        Gets the currently configured value for the requested configuration setting.

        Always returns the value for this session, which may or may not be the persisted
        setting (that all depends on whether or not the setting was previously modified
        during this session using Set-SepmConfiguration -SessionOnly).

        The Git repo for this module can be found here: http://aka.ms/PowerShellForGitHub

    .PARAMETER Name
        The name of the configuration whose value is desired.

    .EXAMPLE
        Get-SepmConfiguration -Name WebRequestTimeoutSec

        Gets the currently configured value for WebRequestTimeoutSec for this PowerShell session
        (which may or may not be the same as the persisted configuration value, depending on
        whether this value was modified during this session with Set-SepmConfiguration -SessionOnly).
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet(
            'ServerAddress',
            'port',
            'username',
            'password',
            'SessionOnly')]
        [string] $Name
    )

    return $script:configuration.$Name
}