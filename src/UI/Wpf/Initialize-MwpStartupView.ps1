function Initialize-MwpStartupView {
    <#
    .SYNOPSIS
        Podpina widok Autostart i harmonogram (Views\Startup.xaml) w instancji modułu Startup i uruchamia pierwszy odczyt w tle.

    .DESCRIPTION
        Stan widoku jest w wpisie instancji ($Entry.Startup), więc dwie instancje (np. localhost
        i komputer zdalny) mają niezależne widoki. Przyciski mają w Tag identyfikator instancji,
        a jedna obsługa (Invoke-MwpStartupViewAction) rozpoznaje akcję po nazwie przycisku. Widok
        nie wywołuje poleceń systemowych — tylko funkcje MWP.Startup i MWP.Core (D-015, D-044, D-046).
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '',
        Justification = 'Parametry obsługi zdarzeń WPF są używane w zagnieżdżonych blokach (Invoke-MwpUiSafe -Action), czego reguła nie widzi.')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable] $Entry
    )

    $p = $Entry.ModuleView.Controls
    $Entry.Startup = @{
        Items        = $null
        Tasks        = $null
        ItemById     = @{}
        TaskByPath   = @{}
        ItemsLoading = $false
        TasksLoading = $false
        ItemsError   = $null
        TasksError   = $null
    }
    $buttons = @('StartupRefreshButton', 'EnableItemButton', 'DisableItemButton', 'EnableTaskButton', 'DisableTaskButton', 'RunTaskButton',
        'RemoveTaskButton', 'StartupUndoButton')
    $handler = {
        param($control)
        Invoke-MwpUiSafe -Name ('UI.Startup.' + $control.Name) -Action {
            $entry = $script:MwpUi.Instances[[string]$control.Tag]
            if ($null -ne $entry) {
                Invoke-MwpStartupViewAction -Entry $entry -Action $control.Name -Owner (Get-MwpOwnerWindow -Element $control)
            }
        }
    }
    foreach ($name in $buttons) {
        $p[$name].Tag = $Entry.Id
        $p[$name].Add_Click($handler)
    }

    # Filtry: zmiana odświeża tylko listy (bez ponownego odczytu z komputera).
    foreach ($pair in @(@('ItemScopeFilter', 'ItemScope'), @('ItemStateFilter', 'ItemState'), @('ItemRiskFilter', 'ItemRisk'), @('TaskStateFilter', 'TaskState'))) {
        $p[$pair[0]].ItemsSource = @(Get-MwpStartupViewOption -Kind $pair[1])
        $p[$pair[0]].SelectedIndex = 0
    }
    $filter = {
        param($control)
        Invoke-MwpUiSafe -Name 'UI.Startup.Filter' -Action {
            $entry = $script:MwpUi.Instances[[string]$control.Tag]
            if ($null -ne $entry) {
                Update-MwpStartupView -Entry $entry -Filter
            }
        }
    }
    foreach ($name in 'ItemScopeFilter', 'ItemStateFilter', 'ItemRiskFilter', 'TaskStateFilter') {
        $p[$name].Tag = $Entry.Id
        $p[$name].Add_SelectionChanged($filter)
    }
    foreach ($name in 'ItemSearchBox', 'TaskSearchBox') {
        $p[$name].Tag = $Entry.Id
        $p[$name].Add_TextChanged($filter)
    }
    foreach ($name in 'TaskHideMicrosoftCheck', 'TaskProtectedFilter') {
        $p[$name].Tag = $Entry.Id
        $p[$name].Add_Click($filter)
    }

    # Wybór pozycji lub zadania: szczegóły i przyciski.
    $selection = {
        param($control)
        Invoke-MwpUiSafe -Name 'UI.Startup.Selection' -Action {
            $entry = $script:MwpUi.Instances[[string]$control.Tag]
            if ($null -ne $entry) {
                Update-MwpStartupView -Entry $entry -Selection
            }
        }
    }
    foreach ($name in 'ItemsGrid', 'TasksGrid', 'StartupUndoGrid') {
        $p[$name].Tag = $Entry.Id
        $p[$name].Add_SelectionChanged($selection)
    }
    Start-MwpUiStartupRefresh -Entry $Entry
}
