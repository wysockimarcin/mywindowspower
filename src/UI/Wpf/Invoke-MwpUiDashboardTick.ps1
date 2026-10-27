function Invoke-MwpUiDashboardTick {
    <#
    .SYNOPSIS
        Krok harmonogramu Dashboardu (wątek okna): uruchamia należne odświeżenia widgetów i odświeża kafelki.

    .DESCRIPTION
        Wywoływana przez zegar okna (Invoke-MwpUiTick) i po kliknięciu „Odśwież”. Odświeżanie
        automatyczne działa tylko wtedy, gdy Pulpit jest widoczny i przełącznik jest włączony;
        odświeżenie ręczne i pierwsze (Pending) — zawsze. Liczbę równoczesnych odświeżeń ogranicza
        dashboardMaxParallelRefresh (Get-MwpWidgetDue); operacje na komputerach dodatkowo ogranicza
        pula MWP.Remote (remoteMaxParallelOperations). Błąd jednego widgetu nie przerywa pozostałych.
    #>
    [CmdletBinding()]
    param()

    $ui = $script:MwpUi
    $dashboard = $ui.Dashboard
    if ($null -eq $dashboard) {
        return
    }
    $auto = $dashboard.AutoRefresh -and [string]$ui.CurrentKey -eq 'dashboard'
    foreach ($widget in @(Get-MwpWidgetDue -Widget @($dashboard.Widgets) -MaxParallel $dashboard.MaxParallel -AutoRefresh $auto)) {
        try {
            $null = Start-MwpWidgetRefresh -Widget $widget -Registry $ui.Tasks
        }
        catch {
            $widget.Status = 'Error'
            $widget.Message = $_.Exception.Message
            $widget.Version++
        }
    }
    if ([string]$ui.CurrentKey -eq 'dashboard') {
        Update-MwpDashboardWidgets
    }
}
