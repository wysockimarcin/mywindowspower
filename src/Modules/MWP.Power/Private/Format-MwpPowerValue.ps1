function Format-MwpPowerValue {
    <#
    .SYNOPSIS
        Zamienia wartość ustawienia zasilania na tekst po polsku (czas: „Nigdy”, „10 min”, „1 godz.”; akcja: „Uśpij”).

    .PARAMETER Kind
        Timeout (sekundy) albo Action (indeks akcji).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowNull()]
        [object] $Value,

        [Parameter(Mandatory)]
        [ValidateSet('Timeout', 'Action')]
        [string] $Kind
    )

    if ($null -eq $Value) {
        return 'brak danych'
    }
    $number = [long]$Value
    if ($Kind -eq 'Action') {
        $labels = (Get-MwpPowerCatalog).ActionLabels
        if ($labels.Contains([int]$number)) {
            return $labels[[int]$number]
        }
        return 'akcja {0}' -f $number
    }
    if ($number -le 0) {
        return 'Nigdy'
    }
    if ($number % 3600 -eq 0) {
        return '{0} godz.' -f ($number / 3600)
    }
    if ($number % 60 -eq 0) {
        return '{0} min' -f ($number / 60)
    }
    '{0} s' -f $number
}
