function Get-MwpWidgetSettingRow {
    <#
    .SYNOPSIS
        Wiersze sekcji „Widżety” widoku „Moduły” (bez WPF): typy widgetów modułu z widocznością na liście „Dodaj widżet” i domyślnymi parametrami.

    .DESCRIPTION
        Dane z katalogu pełnego (Get-MwpWidgetDefinition, D-053): Visible i DefaultParameters już
        uwzględniają ustawienia użytkownika. UserVisible i HasUserDefaults mówią, czy użytkownik zmienił
        wartości z manifestu (przycisk „Przywróć domyślne”). Wynik jest posortowany po nazwie.

    .PARAMETER Definition
        Definicje widgetów (Get-MwpWidgetDefinition).

    .PARAMETER ModuleId
        Id modułu, którego widgety pokazać.

    .PARAMETER WidgetSetting
        Ustawienia użytkownika (Get-MwpWidgetSetting).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [AllowEmptyCollection()]
        [object[]] $Definition = @(),

        [Parameter(Mandatory)]
        [string] $ModuleId,

        [AllowEmptyCollection()]
        [object[]] $WidgetSetting = @()
    )

    $refresh = @{ 0 = 'tylko ręcznie'; 30 = 'co 30 s'; 60 = 'co minutę'; 300 = 'co 5 min'; 900 = 'co 15 min' }
    foreach ($widget in @($Definition | Where-Object { $null -ne $_ -and $_.ModuleId -eq $ModuleId } | Sort-Object -Property Name)) {
        $setting = @($WidgetSetting | Where-Object { $null -ne $_ -and $_.ModuleId -eq $ModuleId -and $_.WidgetId -eq $widget.WidgetId }) | Select-Object -First 1
        $enabled = $(if ($null -ne $widget.PSObject.Properties['Enabled']) { [bool]$widget.Enabled } else { $true })
        $visible = $(if ($null -ne $widget.PSObject.Properties['Visible']) { [bool]$widget.Visible } else { $enabled })
        $remote = $(if ($widget.SupportsRemote) { 'ten komputer i zdalne' } else { 'tylko ten komputer' })
        $refreshText = $(if ($refresh.ContainsKey([int]$widget.DefaultRefreshSeconds)) { $refresh[[int]$widget.DefaultRefreshSeconds] } else { '{0} s' -f $widget.DefaultRefreshSeconds })
        [pscustomobject]@{
            PSTypeName        = 'MWP.UiWidgetSettingRow'
            Key               = $widget.Key
            ModuleId          = $widget.ModuleId
            WidgetId          = $widget.WidgetId
            Title             = '{0}{1}' -f $widget.Name, $(if ($visible) { '' } else { ' (ukryty)' })
            Name              = $widget.Name
            Description       = '{0} Komputery: {1}. Odświeżanie domyślnie: {2}.{3}' -f $widget.Description, $remote, $refreshText, $(if (-not $enabled) { ' Autor modułu domyślnie nie oferuje tego widżetu.' } else { '' })
            Enabled           = $enabled
            Visible           = $visible
            UserVisible       = $(if ($null -ne $setting) { $setting.Visible } else { $null })
            HasUserDefaults   = $null -ne $setting -and $setting.DefaultParameters -is [Collections.IDictionary] -and $setting.DefaultParameters.Count -gt 0
            HasUserSetting    = $null -ne $setting
            Parameters        = $widget.Parameters
            DefaultParameters = $(if ($null -ne $widget.PSObject.Properties['DefaultParameters']) { $widget.DefaultParameters } else { [ordered]@{} })
            Definition        = $widget
        }
    }
}
