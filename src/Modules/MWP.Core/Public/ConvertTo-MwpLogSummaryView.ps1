function ConvertTo-MwpLogSummaryView {
    <#
    .SYNOPSIS
        Zamienia podsumowanie dziennika operacji na widok widgetu „Dziennik operacji” (MWP.WidgetView).

    .DESCRIPTION
        Funkcja widoku z kontraktu widgetu (D-043, D-053): czysta, bez WPF i bez odczytu plików.
        Sekcje: „Dzisiaj” (liczba błędów i ostrzeżeń, zmiany do cofnięcia) i „Ostatnie wpisy”
        (najnowsze wpisy z wybranych poziomów). Zwraca $null, gdy danych nie ma.

    .PARAMETER WidgetParameters
        Parametry widgetu (Levels, Top); dane są już przefiltrowane przez funkcję danych.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'WidgetParameters',
        Justification = 'Parametr wymagany przez kontrakt widgetu (D-043); filtr stosuje funkcja danych.')]
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [AllowNull()]
        [object] $Data,

        [AllowNull()]
        [Collections.IDictionary] $WidgetParameters
    )

    $summary = Resolve-MwpLogSummary -Data $Data
    if ($null -eq $summary) {
        return $null
    }
    $row = {
        param([string] $Label, [string] $Value, [string] $Tone = 'Neutral')
        [pscustomobject]@{ Label = $Label; Value = $(if ($Value) { $Value } else { 'brak danych' }); Percent = -1; Tone = $Tone }
    }
    $todayItems = @(
        & $row 'Błędy' ([string]$summary.Counts.Error) $(if ($summary.Counts.Error -gt 0) { 'Danger' } else { 'Success' })
        & $row 'Ostrzeżenia' ([string]$summary.Counts.Warning) $(if ($summary.Counts.Warning -gt 0) { 'Warning' } else { 'Neutral' })
    )
    if ($null -ne $summary.PendingUndo) {
        $todayItems += & $row 'Zmiany do cofnięcia' ([string]$summary.PendingUndo)
    }
    $entryItems = @(foreach ($entry in @($summary.Entries)) {
            $tone = switch ($entry.Level) { 'Error' { 'Danger' } 'Warning' { 'Warning' } default { 'Neutral' } }
            $time = $(if ($null -ne $entry.Timestamp) { $entry.Timestamp.ToString('HH:mm') } else { '' })
            $message = $entry.Message
            if ($message.Length -gt 120) {
                $message = $message.Substring(0, 117) + '…'
            }
            & $row ('{0} {1}' -f $time, $entry.Operation).Trim() $message $tone
        })
    if ($entryItems.Count -eq 0) {
        $entryItems = @(& $row 'Brak wpisów' $(if ($summary.LogExists) { 'dziś nie ma wpisów z wybranych poziomów' } else { 'dziś nie zapisano jeszcze dziennika' }) 'Success')
    }
    [pscustomobject]@{
        PSTypeName  = 'MWP.WidgetView'
        Summary     = 'Dzisiaj · błędy {0} · ostrzeżenia {1}' -f $summary.Counts.Error, $summary.Counts.Warning
        CollectedAt = $summary.CollectedAt
        Sections    = @(
            [pscustomobject]@{ Title = 'Dzisiaj'; Items = $todayItems }
            [pscustomobject]@{ Title = 'Ostatnie wpisy'; Items = $entryItems }
        )
        Warnings    = @($summary.Warnings)
    }
}
