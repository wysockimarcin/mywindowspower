function Get-MwpPowerOption {
    <#
    .SYNOPSIS
        Zwraca pozycje list rozwijanych widoku Zasilanie: czasy (sekundy) albo akcje przycisków i pokrywy.

    .DESCRIPTION
        Logika prezentacji bez WPF (testy Pester). Czasy: Nigdy, 1–45 min, 1–5 godz.; wartość bieżąca
        spoza listy (np. ustawiona w Panelu sterowania) jest dopisywana, żeby jej nie zgubić.
        Akcje: 0 nic nie rób, 1 uśpij, 2 hibernuj, 3 zamknij system, 4 wyłącz ekran (do -MaxIndex).
        Pozycja: Label, Value.

    .PARAMETER Kind
        Timeout albo Action.

    .PARAMETER Current
        Wartość bieżąca (dopisywana, gdy jej nie ma na liście).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Timeout', 'Action')]
        [string] $Kind,

        [AllowNull()]
        [object] $Current,

        [ValidateRange(0, 4)]
        [int] $MaxIndex = 4
    )

    $items = New-Object -TypeName System.Collections.Generic.List[object]
    if ($Kind -eq 'Action') {
        $labels = @('Nic nie rób', 'Uśpij', 'Hibernuj', 'Zamknij system', 'Wyłącz ekran')
        for ($index = 0; $index -le $MaxIndex; $index++) {
            $items.Add([pscustomobject]@{ Label = $labels[$index]; Value = [long]$index })
        }
        if ($null -ne $Current -and [long]$Current -gt $MaxIndex) {
            $items.Add([pscustomobject]@{ Label = 'akcja {0}' -f $Current; Value = [long]$Current })
        }
        return $items.ToArray()
    }

    $values = @(0, 60, 120, 180, 300, 600, 900, 1200, 1500, 1800, 2700, 3600, 7200, 10800, 14400, 18000)
    if ($null -ne $Current -and $values -notcontains [long]$Current) {
        $values = @($values + [long]$Current | Sort-Object)
    }
    foreach ($value in $values) {
        $label = if ($value -eq 0) { 'Nigdy' } elseif ($value % 3600 -eq 0) { '{0} godz.' -f ($value / 3600) } elseif ($value % 60 -eq 0) { '{0} min' -f ($value / 60) } else { '{0} s' -f $value }
        $items.Add([pscustomobject]@{ Label = $label; Value = [long]$value })
    }
    $items.ToArray()
}
