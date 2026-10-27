function Get-MwpDashboardConfiguration {
    <#
    .SYNOPSIS
        Zwraca zapisaną konfigurację Dashboardu: widgety, odświeżanie automatyczne i limit równoległych odświeżeń.

    .DESCRIPTION
        Konfiguracja leży w ustawieniach lokalnych (config\settings.local.json, poza repozytorium,
        D-043): dashboardWidgets (lista widgetów w kolejności wyświetlania), dashboardAutoRefresh,
        dashboardMaxParallelRefresh. Bez wpisu w pliku lokalnym obowiązuje szablon (jeden widget
        „Informacje o systemie” dla localhost). Niepoprawny wpis widgetu jest pomijany z ostrzeżeniem.
        Funkcja nie sprawdza, czy moduły widgetów istnieją — robi to Repair-MwpDashboardConfiguration.
        Wynik: MWP.DashboardConfiguration (Widgets — słowniki: id, moduleId, widgetId, computerName,
        title, refreshSeconds, size, parameters; AutoRefresh; MaxParallelRefresh; IsDefault; Warnings).

    .EXAMPLE
        (Get-MwpDashboardConfiguration).Widgets | ForEach-Object { $_.computerName }
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $data = Read-MwpSettingsData
    $entries = Get-MwpDashboardWidgetEntry -Data $data
    $warnings = @(@($data.Warnings) + @($entries.Warnings))
    foreach ($warning in $entries.Warnings) {
        Write-MwpLog -Level Warning -Source 'MWP.Core' -Operation 'Dashboard.Read' -Message $warning
    }
    $parallel = 2
    $number = 0
    if ([int]::TryParse([string]$data.Settings['dashboardMaxParallelRefresh'], [ref]$number)) {
        $parallel = [Math]::Min(8, [Math]::Max(1, $number))
    }
    $auto = $true
    if ($data.Settings['dashboardAutoRefresh'] -is [bool]) {
        $auto = $data.Settings['dashboardAutoRefresh']
    }
    [pscustomobject]@{
        PSTypeName         = 'MWP.DashboardConfiguration'
        Widgets            = @($entries.Widgets)
        AutoRefresh        = $auto
        MaxParallelRefresh = $parallel
        IsDefault          = $entries.IsDefault
        Warnings           = $warnings
    }
}
