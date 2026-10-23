function ConvertTo-MwpDateTime {
    <#
    .SYNOPSIS
        Zamienia datę z pliku JSON na [datetime] niezależnie od wersji PowerShella.

    .DESCRIPTION
        ConvertFrom-Json w 7.x sam zamienia tekst ISO 8601 na [datetime], a w 5.1 zostawia tekst.
        Dane zapisujemy jako tekst w formacie 'o', a przy odczycie ujednolicamy typ tą funkcją.
    #>
    [CmdletBinding()]
    [OutputType([datetime])]
    param(
        [AllowNull()]
        [object] $Value
    )

    if ($null -eq $Value -or ($Value -is [string] -and [string]::IsNullOrWhiteSpace($Value))) {
        return $null
    }
    if ($Value -is [datetime]) {
        return $Value
    }
    [datetime]::Parse([string]$Value, [Globalization.CultureInfo]::InvariantCulture,
        [Globalization.DateTimeStyles]::RoundtripKind)
}
