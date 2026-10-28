function Initialize-MwpUpdateView {
    <#
    .SYNOPSIS
        Podpina widok Windows Update (Views\Update.xaml) w instancji modułu Update i uruchamia pierwszy odczyt stanu w tle.

    .DESCRIPTION
        Stan widoku jest w wpisie instancji ($Entry.Update), więc dwie instancje (np. localhost
        i komputer zdalny) mają niezależne widoki, zadania i wyniki. Przyciski mają w Tag identyfikator
        instancji, a jedna obsługa (Invoke-MwpUpdateViewAction) rozpoznaje akcję po nazwie kontrolki.
        Wyszukiwanie aktualizacji (połączenie z serwerem, do kilku minut) i historia nie startują same —
        dopiero przyciskiem. Widok nie wywołuje poleceń systemowych — tylko funkcje MWP.Update
        i MWP.Core (D-015, D-044, D-048).
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '',
        Justification = 'Parametry obsługi zdarzeń WPF są używane w zagnieżdżonych blokach (Invoke-MwpUiSafe -Action), czego reguła nie widzi.')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable] $Entry
    )

    $p = $Entry.ModuleView.Controls
    $Entry.Update = @{
        Status         = $null
        StatusError    = $null
        StatusLoading  = $false
        Search         = $null
        SearchError    = $null
        SearchLoading  = $false
        History        = $null
        HistoryError   = $null
        HistoryLoading = $false
        Task           = $null
        Report         = $null
    }
    $handler = {
        param($control)
        Invoke-MwpUiSafe -Name ('UI.Update.' + $control.Name) -Action {
            $entry = $script:MwpUi.Instances[[string]$control.Tag]
            if ($null -ne $entry) {
                Invoke-MwpUpdateViewAction -Entry $entry -Action $control.Name -Owner (Get-MwpOwnerWindow -Element $control)
            }
        }
    }
    foreach ($name in 'UpdateRefreshButton', 'UpdateSearchButton', 'UpdateInstallButton', 'UpdateSettingsButton', 'UpdateCancelButton',
        'UpdatePauseButton', 'UpdateResumeButton', 'UpdateResetButton', 'UpdateHistoryButton', 'UpdateUndoButton') {
        $p[$name].Tag = $Entry.Id
        $p[$name].Add_Click($handler)
    }
    $p['UpdateTypeBox'].ItemsSource = @(Get-MwpUpdateViewOption -Kind SearchType)
    $p['UpdateTypeBox'].SelectedIndex = 0
    $p['UpdatePauseWeeksBox'].ItemsSource = @(Get-MwpUpdateViewOption -Kind PauseWeeks)
    $p['UpdatePauseWeeksBox'].SelectedIndex = 0

    $selection = {
        param($control)
        Invoke-MwpUiSafe -Name 'UI.Update.Selection' -Action {
            $entry = $script:MwpUi.Instances[[string]$control.Tag]
            if ($null -ne $entry) {
                Update-MwpUpdateView -Entry $entry -Selection
            }
        }
    }
    $p['UpdatesGrid'].Tag = $Entry.Id
    $p['UpdatesGrid'].Add_SelectionChanged($selection)
    $p['UpdateUndoGrid'].Tag = $Entry.Id
    $p['UpdateUndoGrid'].Add_SelectionChanged({
            param($control)
            Invoke-MwpUiSafe -Name 'UI.Update.UndoSelection' -Action {
                $entry = $script:MwpUi.Instances[[string]$control.Tag]
                if ($null -ne $entry) {
                    Update-MwpUpdateView -Entry $entry -StateOnly
                }
            }
        })
    $p['UpdateHistoryFailedCheck'].Tag = $Entry.Id
    $p['UpdateHistoryFailedCheck'].Add_Click({
            param($control)
            Invoke-MwpUiSafe -Name 'UI.Update.HistoryFilter' -Action {
                $entry = $script:MwpUi.Instances[[string]$control.Tag]
                if ($null -ne $entry) {
                    Update-MwpUpdateView -Entry $entry
                }
            }
        })
    Start-MwpUiUpdateRefresh -Entry $Entry
}
