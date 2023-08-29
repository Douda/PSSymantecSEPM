function Set-SepmConfiguration {
    <# TODO update help
    .SYNOPSIS
        Change the value of a configuration property for the PowerShellForGitHub module,
        for the session only, or globally for this user.

    .DESCRIPTION
        Change the value of a configuration property for the PowerShellForGitHub module,
        for the session only, or globally for this user.

        A single call to this method can set any number or combination of properties.

        To change any of the boolean/switch properties to false, specify the switch,
        immediately followed by ":$false" with no space.

        The Git repo for this module can be found here: http://aka.ms/PowerShellForGitHub

    .PARAMETER ServerAddress
        The hostname of the SEPM instance to communicate with. 

    .PARAMETER SessionOnly
        By default, this method will store the configuration values in a local file so that changes
        persist across PowerShell sessions.  If this switch is provided, the file will not be
        created/updated and the specified configuration changes will only remain in memory/effect
        for the duration of this PowerShell session.

    .EXAMPLE
        Set-SepmConfiguration -WebRequestTimeoutSec 120 -SuppressNoTokenWarning

        Changes the timeout permitted for a web request to two minutes, and additionally tells
        the module to never warn about no Access Token being configured.  These settings will be
        persisted across future PowerShell sessions.

    .EXAMPLE
        Set-SepmConfiguration ServerAddress "MySEPMServer"

        Set the SEPM server address to "MySEPMServer" for the duration of this PowerShell session.

#>
    [CmdletBinding(
        PositionalBinding = $false,
        SupportsShouldProcess)]
    param(
        [string] $ServerAddress,

        [int] $port,

        [string] $username,

        [securestring] $password,

        [switch] $SessionOnly
    )

    $persistedConfig = $null
    if (-not $SessionOnly) {
        $persistedConfig = Read-SepmConfiguration -Path $script:configurationFilePath
    }

    if (-not $PSCmdlet.ShouldProcess('SepmConfiguration', 'Set')) {
        return
    }

    $properties = Get-Member -InputObject $script:configuration -MemberType NoteProperty | Select-Object -ExpandProperty Name
    foreach ($name in $properties) {
        if ($PSBoundParameters.ContainsKey($name)) {
            $value = $PSBoundParameters.$name
            if ($value -is [switch]) { $value = $value.ToBool() }
            $script:configuration.$name = $value

            if (-not $SessionOnly) {
                Add-Member -InputObject $persistedConfig -Name $name -Value $value -MemberType NoteProperty -Force
            }
        }
    }

    if (-not $SessionOnly) {
        Save-SepmConfiguration -Configuration $persistedConfig -Path $script:configurationFilePath
    }
}