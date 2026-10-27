function Edit-MwpUiWidget {
    <#
    .SYNOPSIS
        Dodaje nowy widget albo zmienia ustawienia istniejącego (okno Show-MwpWidgetEditor) i zapisuje konfigurację.

    .DESCRIPTION
        Zmiana komputera = nowa instancja modułu dla widgetu (kontekst wykonania jest niezmienny, D-035):
        stara instancja jest zamykana (anulowanie zadania, sesje, poświadczenia), a widget zostaje na
        swoim miejscu. Pozostałe zmiany (nazwa, odświeżanie, rozmiar, parametry) zachowują instancję
        i połączenie; widget jest odświeżany od razu.

    .PARAMETER Id
        Identyfikator edytowanego widgetu; bez niego — nowy widget na końcu Dashboardu.
    #>
    [CmdletBinding()]
    param(
        [AllowEmptyString()]
        [AllowNull()]
        [string] $Id,

        [AllowNull()]
        [object] $Owner
    )

    $ui = $script:MwpUi
    $dashboard = $ui.Dashboard
    $widget = $null
    if ($Id) {
        $widget = @($dashboard.Widgets | Where-Object { $_.Id -eq $Id -and -not $_.Removed }) | Select-Object -First 1
        if ($null -eq $widget) {
            return
        }
    }
    if (@($dashboard.Catalog).Count -eq 0) {
        Show-MwpMessage -Text 'Żaden moduł nie udostępnia widgetów Dashboardu.' -Kind Warning -Owner $Owner
        return
    }
    $config = Show-MwpWidgetEditor -Widget $widget -Catalog @($dashboard.Catalog) -Owner $Owner
    if ($null -eq $config) {
        return
    }
    $definition = @($dashboard.Catalog | Where-Object { $_.ModuleId -eq $config['moduleId'] -and $_.WidgetId -eq $config['widgetId'] }) | Select-Object -First 1

    if ($null -eq $widget) {
        $dashboard.Widgets.Add((New-MwpWidgetRuntime -Configuration $config -Definition $definition))
    }
    elseif ([string]$widget.Config['computerName'] -ne [string]$config['computerName']) {
        $index = $dashboard.Widgets.IndexOf($widget)
        Remove-MwpWidgetRuntime -Widget $widget -Confirm:$false
        $dashboard.Widgets[$index] = New-MwpWidgetRuntime -Configuration $config -Definition $definition
    }
    else {
        $widget.Config = $config
        $widget.Parameters = Get-MwpWidgetParameterSet -Configuration $config -Definition $definition
        $widget.Pending = $true
        $widget.Version++
    }
    Save-MwpUiDashboard
    Invoke-MwpUiDashboardTick
}
