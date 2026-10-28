function Get-MwpCleanupDetail {
    <#
    .SYNOPSIS
        Zwraca tytuł i tekst szczegółów kategorii czyszczenia albo opis wyniku analizy magazynu składników.

    .DESCRIPTION
        Logika prezentacji bez WPF (testy Pester). Kategoria: opis, lokalizacje (użytkownik, stan,
        liczba plików), pominięcia według powodu i przykładowe pominięte ścieżki. Analiza DISM
        (MWP.ComponentStoreAnalysis): rozmiary, data ostatniego czyszczenia, pakiety do odzyskania
        i zalecenie. Wynik: Title i Text.

    .PARAMETER Category
        MWP.CleanupCategoryResult albo $null.

    .PARAMETER Analysis
        MWP.ComponentStoreAnalysis albo $null.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Category')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(ParameterSetName = 'Category')]
        [AllowNull()]
        [object] $Category,

        [Parameter(Mandatory, ParameterSetName = 'Analysis')]
        [AllowNull()]
        [object] $Analysis
    )

    $newLine = [Environment]::NewLine
    if ($PSCmdlet.ParameterSetName -eq 'Analysis') {
        if ($null -eq $Analysis) {
            return [pscustomobject]@{ Title = 'Magazyn składników'; Text = 'Analiza nie była jeszcze wykonana.' }
        }
        if (-not $Analysis.Success) {
            return [pscustomobject]@{ Title = 'Magazyn składników — błąd analizy'; Text = $Analysis.Message }
        }
        $lines = @(
            ('Rozmiar zgłaszany przez Eksplorator: {0}' -f $Analysis.ExplorerSizeText)
            ('Rzeczywisty rozmiar: {0} (współdzielone z Windows: {1}; kopie zapasowe i wyłączone funkcje: {2}; pamięć podręczna i dane tymczasowe: {3})' -f $Analysis.ActualSizeText, $Analysis.SharedText, $Analysis.BackupsText, $Analysis.CacheText)
            ('Ostatnie czyszczenie: {0}' -f $(if ($null -ne $Analysis.LastCleanup) { ([datetime]$Analysis.LastCleanup).ToString('yyyy-MM-dd HH:mm') } elseif ($Analysis.LastCleanupText) { $Analysis.LastCleanupText } else { 'brak danych' }))
            ('Pakiety do odzyskania: {0}' -f $(if ($null -ne $Analysis.ReclaimablePackages) { $Analysis.ReclaimablePackages } else { 'brak danych' }))
            ('Czyszczenie magazynu składników: {0}' -f $(if ($Analysis.CleanupRecommended) { 'ZALECANE (ręcznie, jako administrator: DISM /Online /Cleanup-Image /StartComponentCleanup)' } else { 'niezalecane' }))
            ('Komputer: {0}, analiza: {1}' -f $Analysis.ComputerName, ([datetime]$Analysis.CollectedAt).ToString('yyyy-MM-dd HH:mm'))
        )
        return [pscustomobject]@{ Title = 'Magazyn składników'; Text = $lines -join $newLine }
    }

    if ($null -eq $Category) {
        return [pscustomobject]@{ Title = 'Wybierz kategorię z listy (Ctrl lub Shift — kilka kategorii).'; Text = '' }
    }
    $lines = New-Object -TypeName System.Collections.Generic.List[string]
    if ($Category.Description) {
        $lines.Add([string]$Category.Description)
    }
    $lines.Add(('Do usunięcia: {0} plików, {1}.' -f $Category.FileCount, $Category.SizeText))
    $lines.Add('Lokalizacje:')
    foreach ($root in @($Category.Roots)) {
        $state = if (-not $root.Available) { $root.ReasonText } elseif ($false -eq $root.Exists) { 'nie istnieje' } elseif ($root.Error) { 'błąd: ' + $root.Error } else { '{0} plików, {1}' -f $root.FileCount, (Format-MwpCleanupSize -Bytes $root.SizeBytes) }
        $lines.Add(('  • {0}{1} — {2}' -f $root.Path, $(if ($root.UserName) { ' (' + $root.UserName + ')' } else { '' }), $state))
    }
    if (@($Category.Skipped).Count -gt 0) {
        $lines.Add('Pominięte:')
        foreach ($skip in @($Category.Skipped)) {
            $lines.Add(('  • {0}: {1} ({2})' -f $skip.ReasonText, $skip.Count, $skip.SizeText))
        }
    }
    if (@($Category.Samples).Count -gt 0) {
        $lines.Add('Przykłady pominiętych:')
        foreach ($sample in @($Category.Samples | Select-Object -First 5)) {
            $lines.Add(('  • {0} — {1}' -f $sample.Path, $sample.ReasonText))
        }
    }
    foreach ($note in @($Category.Notes)) {
        $lines.Add([string]$note)
    }
    [pscustomobject]@{ Title = $Category.Name; Text = $lines -join $newLine }
}
