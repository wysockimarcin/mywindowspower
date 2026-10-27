function Save-MwpUiDashboard {
    <#
    .SYNOPSIS
        Zapisuje konfigurację Dashboardu z okna (lista widgetów w kolejności; z -AutoRefresh — przełącznik).

    .DESCRIPTION
        Set-MwpDashboardConfiguration (MWP.Core, D-043): zapis atomowy w ustawieniach lokalnych z logiem.
        Błąd zapisu nie cofa zmian w oknie; pokazuje komunikat.

    .PARAMETER AutoRefresh
        Zapisuje tylko stan przełącznika odświeżania automatycznego.
    #>
    [CmdletBinding()]
    param(
        [switch] $AutoRefresh
    )

    $dashboard = $script:MwpUi.Dashboard
    if ($AutoRefresh) {
        $result = Set-MwpDashboardConfiguration -AutoRefresh $dashboard.AutoRefresh -Confirm:$false
    }
    else {
        $entries = @(ConvertTo-MwpWidgetConfiguration -Widget @($dashboard.Widgets))
        $result = Set-MwpDashboardConfiguration -Widget $entries -Confirm:$false
    }
    if (-not $result.Success) {
        Show-MwpMessage -Text $result.Message -Kind Warning
    }
}
