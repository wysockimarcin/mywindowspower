function ConvertTo-MwpCleanupEstimateView {
    <#
    .SYNOPSIS
        Zamienia wynik skanu czyszczenia na widok widgetu „Miejsce do odzyskania” (MWP.WidgetView).

    .DESCRIPTION
        Funkcja widoku z kontraktu widgetu (D-043, D-053): czysta, bez WPF i bez wywołań systemowych;
        widget tylko pokazuje wynik skanu (niczego nie usuwa — czyszczenie jest w widoku modułu
        z potwierdzeniem). Przyjmuje wynik Measure-MwpCleanupCategory (także surowy wynik operacji
        w tle). Domyślnie tylko suma (minimum miejsca); ShowCategories dodaje kategorie z rozmiarem
        i paskiem udziału w sumie. Zwraca $null, gdy danych nie ma.

    .PARAMETER WidgetParameters
        Parametry widgetu: Categories (skanowane kategorie — wybiera funkcja danych), ShowCategories (bool).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [AllowNull()]
        [object] $Data,

        [AllowNull()]
        [Collections.IDictionary] $WidgetParameters
    )

    if ($null -ne $Data -and $Data.PSObject.TypeNames -contains 'MWP.Result') {
        $Data = $Data.Data
    }
    $scan = Resolve-MwpCleanupScan -Data $Data
    if ($null -eq $scan) {
        return $null
    }
    $showCategories = $null -ne $WidgetParameters -and $WidgetParameters.Contains('ShowCategories') -and [bool]$WidgetParameters['ShowCategories']
    $row = {
        param([string] $Label, [string] $Value, [string] $Tone = 'Neutral', [int] $Percent = -1)
        [pscustomobject]@{ Label = $Label; Value = $(if ($Value) { $Value } else { 'brak danych' }); Percent = $Percent; Tone = $Tone }
    }
    $categories = @($scan.Categories)
    $unavailable = @($categories | Where-Object { -not $_.Available })
    $items = @(
        & $row 'Do odzyskania' $scan.TotalText $(if ($scan.TotalBytes -gt 0) { 'Warning' } else { 'Success' })
        & $row 'Pliki' ([string]$scan.TotalFiles)
    )
    if ($unavailable.Count -gt 0) {
        $items += & $row 'Kategorie niedostępne' ([string]$unavailable.Count)
    }
    $sections = @([pscustomobject]@{ Title = 'Suma'; Items = $items })
    if ($showCategories) {
        $categoryItems = @(foreach ($category in @($categories | Sort-Object -Property SizeBytes -Descending)) {
                if (-not $category.Available) {
                    & $row $category.Name 'niedostępna'
                    continue
                }
                $percent = $(if ($scan.TotalBytes -gt 0) { [int][Math]::Round(100 * $category.SizeBytes / $scan.TotalBytes) } else { 0 })
                & $row $category.Name $category.SizeText 'Neutral' $percent
            })
        $sections += [pscustomobject]@{ Title = 'Kategorie'; Items = $categoryItems }
    }
    $warnings = @($scan.Warnings)
    [pscustomobject]@{
        PSTypeName  = 'MWP.WidgetView'
        Summary     = '{0} · do odzyskania {1}' -f $scan.ComputerName, $scan.TotalText
        CollectedAt = $scan.CollectedAt
        Sections    = $sections
        Warnings    = $warnings
    }
}
