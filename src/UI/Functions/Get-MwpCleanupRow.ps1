function Get-MwpCleanupRow {
    <#
    .SYNOPSIS
        Zamienia wynik skanu (MWP.CleanupScan) na wiersze tabeli kategorii widoku Czyszczenie dysku.

    .DESCRIPTION
        Logika prezentacji bez WPF (testy Pester). Wiersz: Id, Name, FileCount, SizeText, SkippedText
        (liczba i rozmiar pominiętych) i NoteText (niedostępne lokalizacje, błędy, „nic do usunięcia”).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [AllowNull()]
        [object] $Scan
    )

    if ($null -eq $Scan) {
        return
    }
    foreach ($category in @($Scan.Categories | Where-Object { $null -ne $_ })) {
        $notes = @($category.Notes)
        if (-not $category.Available -and $notes.Count -eq 0) {
            $notes = @('Brak dostępnych lokalizacji.')
        }
        elseif ($category.Available -and $category.FileCount -eq 0 -and $notes.Count -eq 0) {
            $notes = @('Nic do usunięcia.')
        }
        [pscustomobject]@{
            Id          = $category.Id
            Name        = $category.Name
            FileCount   = $category.FileCount
            SizeText    = $category.SizeText
            SkippedText = $(if ($category.SkippedCount -gt 0) { '{0} ({1})' -f $category.SkippedCount, $category.SkippedText } else { '' })
            NoteText    = $notes -join ' '
        }
    }
}
