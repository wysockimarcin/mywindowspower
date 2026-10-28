function ConvertTo-MwpUpdatePauseText {
    <#
    .SYNOPSIS
        Zwraca wartość pauzy w postaci zapisywanej w rejestrze (tekst ISO 8601 w UTC, np. 2026-11-04T10:00:00Z) albo $null.

    .DESCRIPTION
        ConvertFrom-Json w 7.x zamienia taki tekst na [datetime] — tu wraca on do postaci tekstowej
        (wartość do zapisu i do wpisu cofnięcia jest wtedy taka sama w 5.1 i 7.x). Tekst jest
        zwracany bez zmian; pusta wartość daje $null.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowNull()]
        [object] $Value
    )

    if ($null -eq $Value) {
        return $null
    }
    if ($Value -is [datetime]) {
        $utc = if ($Value.Kind -eq [DateTimeKind]::Local) { $Value.ToUniversalTime() } else { $Value }
        return $utc.ToString("yyyy-MM-dd'T'HH:mm:ss'Z'", [Globalization.CultureInfo]::InvariantCulture)
    }
    $text = [string]$Value
    if ($text -eq '') {
        return $null
    }
    $text
}
