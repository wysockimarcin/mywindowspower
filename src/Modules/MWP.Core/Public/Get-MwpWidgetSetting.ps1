function Get-MwpWidgetSetting {
    <#
    .SYNOPSIS
        Zwraca ustawienia użytkownika dla typów widgetów modułów: widoczność na liście „Dodaj widżet” i domyślne parametry nowych widgetów.

    .DESCRIPTION
        Ustawienia leżą w settings.local.json pod kluczem modules: modules.<Id modułu>.widgets.<Id widgetu>
        z polami visible (bool) i defaultParameters (obiekt zgodny ze schematem Parameters widgetu) — D-053.
        Brak wpisu oznacza zachowanie z manifestu (Widgets[].Enabled, Parameters.Default). Wpisy
        nieczytelne (np. visible niebędące wartością logiczną) są pomijane. Wynik: obiekty
        MWP.WidgetSetting (ModuleId, WidgetId, Visible — $true, $false albo $null, DefaultParameters).

    .PARAMETER ModuleId
        Tylko ustawienia widgetów tego modułu.

    .EXAMPLE
        Get-MwpWidgetSetting -ModuleId Dashboard
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [ValidateNotNullOrEmpty()]
        [string] $ModuleId
    )

    $data = Read-MwpSettingsData -NoRepair
    $modules = $null
    if ($data.Settings.Contains('modules')) {
        $modules = $data.Settings['modules']
    }
    if ($modules -isnot [Collections.IDictionary]) {
        return
    }
    foreach ($moduleKey in @($modules.Keys)) {
        if ($PSBoundParameters.ContainsKey('ModuleId') -and [string]$moduleKey -ne $ModuleId) {
            continue
        }
        $module = $modules[$moduleKey]
        if ($module -isnot [Collections.IDictionary] -or $module['widgets'] -isnot [Collections.IDictionary]) {
            continue
        }
        foreach ($widgetKey in @($module['widgets'].Keys)) {
            $entry = $module['widgets'][$widgetKey]
            if ($entry -isnot [Collections.IDictionary]) {
                continue
            }
            $visible = $null
            if ($entry.Contains('visible') -and $entry['visible'] -is [bool]) {
                $visible = [bool]$entry['visible']
            }
            $defaults = [ordered]@{}
            if ($entry['defaultParameters'] -is [Collections.IDictionary]) {
                foreach ($key in @($entry['defaultParameters'].Keys)) {
                    $defaults[[string]$key] = $entry['defaultParameters'][$key]
                }
            }
            [pscustomobject]@{
                PSTypeName        = 'MWP.WidgetSetting'
                ModuleId          = [string]$moduleKey
                WidgetId          = [string]$widgetKey
                Visible           = $visible
                DefaultParameters = $defaults
            }
        }
    }
}
