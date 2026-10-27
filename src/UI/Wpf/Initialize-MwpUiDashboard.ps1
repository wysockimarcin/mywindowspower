function Initialize-MwpUiDashboard {
    <#
    .SYNOPSIS
        Odtwarza Dashboard z zapisanej konfiguracji: widgety, odświeżanie automatyczne, limit odświeżeń.

    .DESCRIPTION
        Repair-MwpDashboardConfiguration sprawdza zapisane widgety z modułami: widgety modułów, których
        już nie ma, są pomijane i usuwane z zapisu (D-031), a ostrzeżenie trafia do banera Pulpitu.
        Każdy pozostały widget dostaje własną instancję modułu (New-MwpWidgetRuntime); błąd jednego nie
        przerywa odtwarzania pozostałych. Pierwsze odświeżenie wszystkich widgetów wykonuje zegar okna
        (Invoke-MwpUiDashboardTick) z limitem równoczesnych odświeżeń.
    #>
    [CmdletBinding()]
    param()

    $ui = $script:MwpUi
    $ui.Definitions = @(Get-MwpModuleDefinition)
    $repair = Repair-MwpDashboardConfiguration -Definition $ui.Definitions -Confirm:$false
    $configuration = $repair.Data.Configuration
    # Lista przez ::new(), nie New-Object: w 5.1 @(...) na liście opakowanej w PSObject i trzymanej w tabeli
    # kończy się błędem „Niezgodne typy argumentów” (PSToObjectArrayBinder).
    $dashboard = @{
        Widgets     = [System.Collections.Generic.List[object]]::new()
        Catalog     = @(Get-MwpWidgetDefinition -Definition $ui.Definitions)
        AutoRefresh = [bool]$configuration.AutoRefresh
        MaxParallel = [int]$configuration.MaxParallelRefresh
        Signature   = $null
        Banner      = $null
    }
    $ui.Dashboard = $dashboard
    foreach ($item in @($repair.Data.Widgets)) {
        $dashboard.Widgets.Add((New-MwpWidgetRuntime -Configuration $item.Widget -Definition $item.Definition))
    }

    $notes = @()
    if (@($repair.Data.Removed).Count -gt 0) {
        $notes += 'Pominięto i usunięto z konfiguracji widgety modułów, których już nie ma: {0}.' -f
        (@($repair.Data.Removed | ForEach-Object { '{0} ({1})' -f $_.Widget.widgetId, $_.Reason }) -join '; ')
    }
    if (@($repair.Data.Unavailable).Count -gt 0) {
        $notes += 'Nie odtworzono widgetów modułów z błędnym kontraktem: {0}.' -f
        (@($repair.Data.Unavailable | ForEach-Object { '{0} ({1})' -f $_.Widget.widgetId, $_.Reason }) -join '; ')
    }
    if (@($configuration.Warnings).Count -gt 0) {
        $notes += @($configuration.Warnings)
    }
    if (-not $repair.Success) {
        $notes += $repair.Message
    }
    if ($notes.Count -gt 0) {
        $dashboard.Banner = $notes -join ' '
    }
}
