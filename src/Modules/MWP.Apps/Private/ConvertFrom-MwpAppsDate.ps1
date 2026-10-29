function ConvertFrom-MwpAppsDate {
    <#
    .SYNOPSIS
        Data z bloku (tekst ISO 8601 w 5.1, [datetime] w 7.x po ConvertFrom-Json) jako [datetime] albo $null.
    #>
    [CmdletBinding()]
    [OutputType([datetime])]
    param(
        [AllowNull()]
        [object] $Value
    )

    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) {
        return $null
    }
    if ($Value -is [datetime]) {
        return $Value
    }
    $parsed = [datetime]::MinValue
    if ([datetime]::TryParse([string]$Value, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::RoundtripKind, [ref]$parsed)) {
        return $parsed
    }
    $null
}
