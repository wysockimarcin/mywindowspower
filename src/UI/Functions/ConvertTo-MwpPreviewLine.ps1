function ConvertTo-MwpPreviewLine {
    <#
    .SYNOPSIS
        Zamienia wynik podglądu (MWP.Result z -WhatIf) na linie „Podglądu zmian" w oknie potwierdzenia.

    .DESCRIPTION
        GUI pokazuje zmianę, zanim ją wykona (ARCHITEKTURA.md, „Zasady bezpieczeństwa zmian"):
        funkcja logiki wywołana z -WhatIf zwraca wynik z IsPreview, a ta funkcja układa z niego
        tekst: komunikat, komputer docelowy, stan przed i po (tabele jako „klucz: wartość").
        Wynik niebędący podglądem (np. odmowa walidacji) daje linię z komunikatem błędu.

    .PARAMETER Result
        Wynik MWP.Result.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [PSTypeName('MWP.Result')]
        [object] $Result
    )

    $format = {
        param($Value)
        if ($null -eq $Value) {
            return '(brak)'
        }
        if ($Value -is [Collections.IDictionary]) {
            return (@(foreach ($key in $Value.Keys) { '{0}: {1}' -f $key, $Value[$key] }) -join '; ')
        }
        if ($Value -is [string]) {
            if ($Value -eq '') { return '(pusta wartość)' }
            return $Value
        }
        if ($Value -is [Collections.IEnumerable]) {
            return (@($Value | ForEach-Object { [string]$_ }) -join ', ')
        }
        [string]$Value
    }

    if (-not $Result.Success) {
        'Nie można wykonać: {0}' -f $Result.Message
        return
    }
    $Result.Message
    'Komputer: {0}' -f (Format-MwpTargetLabel -ComputerName $Result.ComputerName)
    if ($null -ne $Result.Before) {
        'Przed: {0}' -f (& $format $Result.Before)
    }
    if ($null -ne $Result.After) {
        'Po: {0}' -f (& $format $Result.After)
    }
}
