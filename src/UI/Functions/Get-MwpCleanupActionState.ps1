function Get-MwpCleanupActionState {
    <#
    .SYNOPSIS
        Wylicza dostępność przycisków widoku Czyszczenie dysku i treść okna potwierdzenia dla zaznaczonych kategorii.

    .DESCRIPTION
        Logika prezentacji bez WPF (testy Pester). Czyścić można tylko kategorie z ostatniego skanu,
        które są dostępne i mają pliki do usunięcia; skan i czyszczenie wymagają gotowej instancji
        (połączenie, brak trwających zadań). Wynik: CanScan, CanRun, CanSelectAll, Categories (kategorie
        do wyczyszczenia), SelectionText, PreviewLine (kategoria — liczba plików i rozmiar, do okna
        potwierdzenia), TotalBytes i TotalText. Blokady egzekwuje też Clear-MwpCleanupCategory
        (administrator, lokalizacje, profile zdalne).

    .PARAMETER Scan
        Ostatni wynik skanu (MWP.CleanupScan) albo $null.

    .PARAMETER SelectedId
        Identyfikatory zaznaczonych kategorii.

    .PARAMETER Ready
        Instancja połączona i nic nie trwa.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [AllowNull()]
        [object] $Scan,

        [AllowEmptyCollection()]
        [string[]] $SelectedId = @(),

        [bool] $Ready = $true
    )

    $categories = @()
    $selectable = @()
    if ($null -ne $Scan) {
        $selectable = @($Scan.Categories | Where-Object { $null -ne $_ -and $_.Available -and $_.FileCount -gt 0 })
        $categories = @($selectable | Where-Object { $SelectedId -contains $_.Id })
    }
    $total = [long]0
    $files = [long]0
    $lines = @(foreach ($category in $categories) {
            $total += [long]$category.SizeBytes
            $files += [long]$category.FileCount
            '{0}: {1} plików, {2}' -f $category.Name, $category.FileCount, $category.SizeText
        })
    $totalText = Format-MwpCleanupSize -Bytes $total
    $ignored = @($SelectedId).Count - $categories.Count
    $selectionText = if ($categories.Count -gt 0) {
        'Zaznaczono {0} kat. do wyczyszczenia: {1} plików, {2}{3}.' -f $categories.Count, $files, $totalText, $(if ($ignored -gt 0) { ' (pozostałe zaznaczone nie mają nic do usunięcia albo są niedostępne)' } else { '' })
    }
    elseif (@($SelectedId).Count -gt 0) {
        'Zaznaczone kategorie nie mają nic do usunięcia albo są niedostępne.'
    }
    elseif ($null -ne $Scan) {
        'Zaznacz kategorie do wyczyszczenia (łącznie do zwolnienia: {0}).' -f $Scan.TotalText
    }
    else {
        ''
    }
    [pscustomobject]@{
        CanScan       = $Ready
        CanRun        = $Ready -and $categories.Count -gt 0
        CanSelectAll  = $Ready -and $selectable.Count -gt 0
        Categories    = $categories
        SelectionText = $selectionText
        PreviewLine   = @($lines + @(('Razem: {0} plików, {1} (rozmiar z ostatniego skanu; pliki w użyciu zostaną pominięte).' -f $files, $totalText)))
        TotalBytes    = $total
        TotalText     = $totalText
    }
}
