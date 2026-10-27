function Move-MwpUiWidget {
    <#
    .SYNOPSIS
        Przesuwa widget o jedno miejsce wcześniej albo dalej na Dashboardzie i zapisuje kolejność.

    .PARAMETER Id
        Identyfikator widgetu.

    .PARAMETER Offset
        -1 (wcześniej) albo 1 (dalej).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Id,

        [Parameter(Mandatory)]
        [ValidateSet(-1, 1)]
        [int] $Offset
    )

    $widgets = $script:MwpUi.Dashboard.Widgets
    $widget = @($widgets | Where-Object { $_.Id -eq $Id }) | Select-Object -First 1
    if ($null -eq $widget) {
        return
    }
    $index = $widgets.IndexOf($widget)
    $target = $index + $Offset
    if ($target -lt 0 -or $target -ge $widgets.Count) {
        return
    }
    $widgets.RemoveAt($index)
    $widgets.Insert($target, $widget)
    Save-MwpUiDashboard
    Update-MwpDashboardWidgets -Force
}
