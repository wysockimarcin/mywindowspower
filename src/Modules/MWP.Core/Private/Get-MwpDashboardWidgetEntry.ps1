function Get-MwpDashboardWidgetEntry {
    <#
    .SYNOPSIS
        Czyta wpisy widgetów Dashboardu (dashboardWidgets) jako ujednolicone słowniki i ostrzeżenia.

    .DESCRIPTION
        Niepoprawny wpis jest pomijany z ostrzeżeniem (nie blokuje pozostałych widgetów); powtórzony
        identyfikator — tak samo. Zwraca tabelę: Widgets (lista słowników), Warnings, IsDefault
        (plik lokalny nie ma klucza dashboardWidgets, więc obowiązuje szablon).

    .PARAMETER Data
        Wynik Read-MwpSettingsData, gdy wywołujący już go ma.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Collections.IDictionary] $Data
    )

    if ($null -eq $Data) {
        $Data = Read-MwpSettingsData
    }
    $warnings = New-Object -TypeName System.Collections.Generic.List[string]
    $widgets = New-Object -TypeName System.Collections.Generic.List[object]
    $ids = @{}
    $raw = $null
    if ($Data.Settings.Contains('dashboardWidgets')) {
        $raw = $Data.Settings['dashboardWidgets']
    }
    foreach ($entry in @($raw | Where-Object { $null -ne $_ })) {
        try {
            $widget = ConvertTo-MwpDashboardWidget -InputObject $entry
            if ($ids.ContainsKey($widget.id)) {
                throw ("Powtórzony identyfikator widgetu '{0}'." -f $widget.id)
            }
            $ids[$widget.id] = $true
            $widgets.Add($widget)
        }
        catch {
            $warnings.Add(("Pominięto wpis Dashboardu: {0}" -f $_.Exception.Message))
        }
    }
    @{
        Widgets   = $widgets.ToArray()
        Warnings  = $warnings.ToArray()
        IsDefault = -not $Data.Local.Contains('dashboardWidgets')
    }
}
