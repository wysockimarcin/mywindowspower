function ConvertFrom-MwpUpdateDate {
    <#
    .SYNOPSIS
        Zamienia datę z bloku MWP.Update (tekst ISO 8601 w UTC albo [datetime]) na czas lokalny; zwraca $null, gdy daty brak lub jest niepoprawna.

    .DESCRIPTION
        ConvertFrom-Json w 7.x zamienia tekst ISO 8601 na [datetime], w 5.1 zostawia tekst — obie postacie
        są obsługiwane. Daty sprzed 2000 r. (wartości „nigdy” Windows Update Agent) dają $null.
    #>
    [CmdletBinding()]
    [OutputType([datetime])]
    param(
        [AllowNull()]
        [object] $Value
    )

    if ($null -eq $Value) {
        return $null
    }
    $date = $null
    if ($Value -is [datetime]) {
        $date = $Value
    }
    else {
        $text = [string]$Value
        if ([string]::IsNullOrWhiteSpace($text)) {
            return $null
        }
        $parsed = [datetime]::MinValue
        $styles = [Globalization.DateTimeStyles]::AdjustToUniversal -bor [Globalization.DateTimeStyles]::AssumeUniversal
        if (-not [datetime]::TryParse($text, [Globalization.CultureInfo]::InvariantCulture, $styles, [ref]$parsed)) {
            return $null
        }
        $date = [datetime]::SpecifyKind($parsed, [DateTimeKind]::Utc)
    }
    if ($date.Year -lt 2000) {
        return $null
    }
    if ($date.Kind -eq [DateTimeKind]::Unspecified) {
        $date = [datetime]::SpecifyKind($date, [DateTimeKind]::Utc)
    }
    $date.ToLocalTime()
}
