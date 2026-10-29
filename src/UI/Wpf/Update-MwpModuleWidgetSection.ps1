function Update-MwpModuleWidgetSection {
    <#
    .SYNOPSIS
        Wypełnia sekcję „Widżety” widoku „Moduły” dla wybranego modułu: typy widgetów, widoczność i domyślne parametry (D-053).

    .DESCRIPTION
        Wiersze buduje Get-MwpWidgetSettingRow (katalog pełny z ustawieniami użytkownika), kontrolki
        parametrów — New-MwpUiWidgetParameterPanel (te same co w oknie widgetu). Zmiana pola wyboru albo
        wyjście z pola tekstowego zapisuje domyślne parametry od razu (Save-MwpUiWidgetSetting).
        Sekcja jest ukryta, gdy moduł nie ma widgetów albo ma błędny kontrakt.

    .PARAMETER WidgetId
        Typ widgetu do zaznaczenia (np. po zapisie); domyślnie bieżący albo pierwszy.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Zmienia tylko kontrolki okna.')]
    [CmdletBinding()]
    param(
        [AllowEmptyString()]
        [AllowNull()]
        [string] $WidgetId
    )

    $ui = $script:MwpUi
    $v = $ui.Views['modules'].Controls
    $module = $v['ModulesGrid'].SelectedItem
    if ($null -eq $module -or -not $module.IsValid) {
        $v['WidgetsCard'].Visibility = 'Collapsed'
        return
    }
    $settings = @(Get-MwpWidgetSetting -ModuleId $module.Id)
    $definitions = @(Get-MwpWidgetDefinition -Definition $ui.Definitions -ModuleId $module.Id -WidgetSetting $settings)
    $rows = @(Get-MwpWidgetSettingRow -Definition $definitions -ModuleId $module.Id -WidgetSetting $settings)
    if ($rows.Count -eq 0) {
        $v['WidgetsCard'].Visibility = 'Collapsed'
        return
    }
    $v['WidgetsCard'].Visibility = 'Visible'
    if (-not $WidgetId -and $null -ne $v['WidgetTypeCombo'].SelectedItem -and $v['WidgetTypeCombo'].SelectedItem.ModuleId -eq $module.Id) {
        $WidgetId = $v['WidgetTypeCombo'].SelectedItem.WidgetId
    }
    $visibleCount = @($rows | Where-Object { $_.Visible }).Count
    $v['ModuleWidgetsCheck'].IsChecked = $(if ($visibleCount -eq $rows.Count) { $true } elseif ($visibleCount -eq 0) { $false } else { $null })
    $ui.Views['modules'].WidgetRows = $rows
    $ui.Views['modules'].WidgetUpdating = $true
    try {
        $v['WidgetTypeCombo'].ItemsSource = $rows
        $v['WidgetTypeCombo'].SelectedItem = @($rows | Where-Object { $_.WidgetId -eq $WidgetId }) + @($rows) | Select-Object -First 1
    }
    finally {
        $ui.Views['modules'].WidgetUpdating = $false
    }
    $row = $v['WidgetTypeCombo'].SelectedItem
    $v['WidgetDescriptionText'].Text = $row.Description
    $v['WidgetVisibleCheck'].IsChecked = $row.Visible
    $v['WidgetResetButton'].IsEnabled = $row.HasUserSetting
    $fields = @(Get-MwpWidgetParameterField -Schema $row.Parameters -Value $row.DefaultParameters)
    $v['WidgetParametersHeader'].Visibility = $(if ($fields.Count -gt 0) { 'Visible' } else { 'Collapsed' })
    $save = {
        Invoke-MwpUiSafe -Name 'UI.Modules.WidgetDefaults' -Action { Save-MwpUiWidgetSetting -DefaultParameters }
    }
    $ui.Views['modules'].WidgetParameters = New-MwpUiWidgetParameterPanel -Panel $v['WidgetParametersPanel'] -Field $fields -OnChange $save
    $v['WidgetStatusText'].Text = $(if ($row.HasUserSetting) { 'Zmienione przez Ciebie (zapis w settings.local.json).' } else { 'Wartości z manifestu modułu.' })
}
