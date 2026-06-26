function Convert-CamelToSnake {
    <#
    .SYNOPSIS
        Converts CamelCase to snake_case (e.g. ClientDefVersions → client_def_versions).
    #>
    param([string]$Name)

    $snake = $Name -creplace '([a-z])([A-Z])', '$1_$2'
    return $snake.ToLower()
}
