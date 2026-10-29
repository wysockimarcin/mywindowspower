function Save-MwpUiWidgetSetting {
    <#
    .SYNOPSIS
        Zapisuje zmianę z sekcji „Widżety” widoku „Moduły” (Set-MwpWidgetSetting) i odświeża sekcję.

    .DESCRIPTION
        Zapis od razu po zmianie (D-053): widoczność wybranego typu, widoczność wszystkich typów modułu
        („Moduł dostępny jako widżet” — skrót ustawiający visible dla każdego typu), domyślne parametry
        wybranego typu albo przywrócenie wartości z manifestu. Lista w oknie „Dodaj widżet” jest czytana
        przy każdym otwarciu, więc zmiana działa bez ponownego uruchomienia. Błąd zapisu — komunikat
        w sekcji (wynik bez wyjątku).

    .PARAMETER Visible
        Nowa widoczność wybranego typu.

    .PARAMETER ModuleVisible
        Nowa widoczność wszystkich typów modułu.

    .PARAMETER DefaultParameters
        Zapis domyślnych parametrów z kontrolek.

    .PARAMETER Reset
        Przywrócenie wartości z manifestu dla wybranego typu.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '',
        Justification = 'Przełączniki DefaultParameters i Reset wybierają zestaw parametrów (ParameterSetName).')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Potwierdzenie nie jest potrzebne: zapis stanu aplikacji (Set-MwpWidgetSetting loguje zmianę).')]
    [CmdletBinding(DefaultParameterSetName = 'Visible')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Visible')]
        [bool] $Visible,

        [Parameter(Mandatory, ParameterSetName = 'Module')]
        [bool] $ModuleVisible,

        [Parameter(Mandatory, ParameterSetName = 'Defaults')]
        [switch] $DefaultParameters,

        [Parameter(Mandatory, ParameterSetName = 'Reset')]
        [switch] $Reset
    )

    $ui = $script:MwpUi
    $view = $ui.Views['modules']
    $v = $view.Controls
    $module = $v['ModulesGrid'].SelectedItem
    $row = $v['WidgetTypeCombo'].SelectedItem
    if ($null -eq $module -or $null -eq $row -or $view.WidgetUpdating) {
        return
    }
    $common = @{ ModuleId = $module.Id; Definition = $ui.Definitions; Confirm = $false }
    $result = switch ($PSCmdlet.ParameterSetName) {
        'Visible' { Set-MwpWidgetSetting @common -WidgetId $row.WidgetId -Visible $Visible }
        'Module' { Set-MwpWidgetSetting @common -WidgetId @($view.WidgetRows | ForEach-Object { $_.WidgetId }) -Visible $ModuleVisible }
        'Reset' { Set-MwpWidgetSetting @common -WidgetId $row.WidgetId -Reset }
        'Defaults' {
            $read = & $view.WidgetParameters.Read
            if ($read.Problem) {
                $v['WidgetStatusText'].Text = 'Nie zapisano: {0}' -f $read.Problem
                return
            }
            Set-MwpWidgetSetting @common -WidgetId $row.WidgetId -DefaultParameters $read.Parameters
        }
    }
    if ($PSCmdlet.ParameterSetName -eq 'Defaults' -and $result.Success) {
        # Bez przebudowy kontrolek: użytkownik może dalej edytować pola.
        $v['WidgetStatusText'].Text = 'Zapisano domyślne parametry nowych widżetów.'
        $v['WidgetResetButton'].IsEnabled = $true
        return
    }
    Update-MwpModuleWidgetSection -WidgetId $row.WidgetId
    if (-not $result.Success) {
        $v['WidgetStatusText'].Text = $result.Message
    }
}
