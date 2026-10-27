function Remove-MwpUiWidget {
    <#
    .SYNOPSIS
        Usuwa widget z Dashboardu: anuluje jego zadanie, zamyka instancję i zapisuje konfigurację.

    .DESCRIPTION
        Nie zmienia systemu (usunięcie kafelka; widget można dodać ponownie), dlatego bez okna
        potwierdzenia. Pozostałe widgety działają dalej (Remove-MwpWidgetRuntime).

    .PARAMETER Id
        Identyfikator widgetu.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Id
    )

    $ui = $script:MwpUi
    $dashboard = $ui.Dashboard
    $widget = @($dashboard.Widgets | Where-Object { $_.Id -eq $Id }) | Select-Object -First 1
    if ($null -eq $widget -or -not $PSCmdlet.ShouldProcess(('widget {0}' -f $Id), 'Usunięcie z Dashboardu')) {
        return
    }
    Remove-MwpWidgetRuntime -Widget $widget -Confirm:$false
    $null = $dashboard.Widgets.Remove($widget)
    Save-MwpUiDashboard
    Update-MwpDashboardWidgets -Force
}
