function ConvertFrom-MwpNetworkDate {
    <#
    .SYNOPSIS
        Zamienia datę z bloku (tekst ISO 8601 albo [datetime] — ConvertFrom-Json w 7.x zamienia tekst sam) na [datetime] czasu lokalnego; brak — $null.
    #>
    [CmdletBinding()]
    [OutputType([datetime])]
    param(
        [AllowNull()]
        [object] $Value
    )

    if ($null -eq $Value -or [string]$Value -eq '') {
        return $null
    }
    if ($Value -is [datetime]) {
        return $Value.ToLocalTime()
    }
    $parsed = [datetime]::MinValue
    if ([datetime]::TryParse([string]$Value, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::RoundtripKind, [ref]$parsed)) {
        return $parsed.ToLocalTime()
    }
    $null
}
