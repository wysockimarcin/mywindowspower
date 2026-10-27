function Initialize-MwpPowerView {
    <#
    .SYNOPSIS
        Podpina widok Zasilanie (Views\Power.xaml) w instancji modułu Power i uruchamia pierwszy odczyt stanu w tle.

    .DESCRIPTION
        Stan widoku jest w wpisie instancji ($Entry.Power), więc dwie instancje (np. localhost
        i komputer zdalny) mają niezależne widoki. Przyciski mają w Tag identyfikator instancji,
        a jedna obsługa (Invoke-MwpPowerViewAction) rozpoznaje akcję po nazwie przycisku. Widok
        nie wywołuje poleceń systemowych — tylko funkcje MWP.Power (D-015, D-044).
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '',
        Justification = 'Parametry obsługi zdarzeń WPF są używane w zagnieżdżonych blokach (Invoke-MwpUiSafe -Action), czego reguła nie widzi.')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable] $Entry
    )

    $p = $Entry.ModuleView.Controls
    $Entry.Power = @{
        Status     = $null
        FilledFor  = $null
        Loading    = $false
        Error      = $null
        LastReport = $null
        Reporting  = $false
    }
    $buttons = @('PowerRefreshButton', 'ActivatePlanButton', 'UltimatePlanButton', 'RemovePlanButton', 'CopyPlanButton', 'RenamePlanButton',
        'ApplySettingsButton', 'ResetSettingsButton', 'BatteryReportButton', 'EnergyReportButton', 'OpenReportButton', 'UndoButton')
    $handler = {
        param($control)
        Invoke-MwpUiSafe -Name ('UI.Power.' + $control.Name) -Action {
            $entry = $script:MwpUi.Instances[[string]$control.Tag]
            if ($null -ne $entry) {
                Invoke-MwpPowerViewAction -Entry $entry -Action $control.Name -Owner (Get-MwpOwnerWindow -Element $control)
            }
        }
    }
    foreach ($name in $buttons) {
        $p[$name].Tag = $Entry.Id
        $p[$name].Add_Click($handler)
    }
    $selection = {
        param($control)
        Invoke-MwpUiSafe -Name 'UI.Power.Selection' -Action {
            $entry = $script:MwpUi.Instances[[string]$control.Tag]
            if ($null -ne $entry) {
                Update-MwpPowerView -Entry $entry -StateOnly
            }
        }
    }
    foreach ($name in 'PlansGrid', 'UndoGrid') {
        $p[$name].Tag = $Entry.Id
        $p[$name].Add_SelectionChanged($selection)
    }
    try {
        $p['ReportFolderBox'].Text = Get-MwpPowerReportDirectory
    }
    catch {
        $p['ReportFolderBox'].Text = ''
    }
    Start-MwpUiPowerRefresh -Entry $Entry
}
