function Initialize-MwpAppsView {
    <#
    .SYNOPSIS
        Podpina widok aplikacji (Views\Apps.xaml) w instancji modułu Apps i uruchamia pierwszy odczyt programów i pakietów winget w tle.

    .DESCRIPTION
        Stan widoku jest w wpisie instancji ($Entry.Apps), więc dwie instancje (np. localhost i komputer
        zdalny) mają niezależne widoki, zadania i wyniki. Przyciski mają w Tag identyfikator instancji,
        a jedna obsługa (Invoke-MwpAppsViewAction) rozpoznaje akcję po nazwie kontrolki. Filtry
        (wyszukiwanie, źródło, zakres, składniki systemowe, tylko z aktualizacją) przeliczają listę bez
        ponownego odczytu. Widok nie wywołuje poleceń systemowych — tylko funkcje MWP.Apps i MWP.Core
        (D-015, D-044, D-050).
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '',
        Justification = 'Parametry obsługi zdarzeń WPF są używane w zagnieżdżonych blokach (Invoke-MwpUiSafe -Action), czego reguła nie widzi.')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable] $Entry
    )

    $p = $Entry.ModuleView.Controls
    $Entry.Apps = @{
        Inventory        = $null
        InventoryError   = $null
        InventoryLoading = $false
        InventoryReadAt  = $null
        Packages         = $null
        PackagesError    = $null
        PackagesLoading  = $false
        Search           = $null
        SearchError      = $null
        SearchLoading    = $false
        SearchQuery      = ''
        UserSid          = @()
    }
    $handler = {
        param($control)
        Invoke-MwpUiSafe -Name ('UI.Apps.' + $control.Name) -Action {
            $entry = $script:MwpUi.Instances[[string]$control.Tag]
            if ($null -ne $entry) {
                Invoke-MwpAppsViewAction -Entry $entry -Action $control.Name -Owner (Get-MwpOwnerWindow -Element $control)
            }
        }
    }
    foreach ($name in 'AppsRefreshButton', 'AppsProfileButton', 'AppsUpgradeButton', 'AppsUninstallButton', 'UpgradesRefreshButton',
        'UpgradeSelectedButton', 'SearchButton', 'InstallButton', 'AppsUndoButton') {
        $p[$name].Tag = $Entry.Id
        $p[$name].Add_Click($handler)
    }
    $p['AppsSourceBox'].ItemsSource = @(Get-MwpAppsViewOption -Kind Source)
    $p['AppsSourceBox'].SelectedIndex = 0
    $p['AppsScopeBox'].ItemsSource = @(Get-MwpAppsViewOption -Kind Scope)
    $p['AppsScopeBox'].SelectedIndex = 0

    $filter = {
        param($control)
        Invoke-MwpUiSafe -Name 'UI.Apps.Filter' -Action {
            $entry = $script:MwpUi.Instances[[string]$control.Tag]
            if ($null -ne $entry) {
                Update-MwpAppsView -Entry $entry -Filter
            }
        }
    }
    foreach ($name in 'AppsSourceBox', 'AppsScopeBox') {
        $p[$name].Tag = $Entry.Id
        $p[$name].Add_SelectionChanged($filter)
    }
    foreach ($name in 'AppsSystemCheck', 'AppsUpgradeCheck') {
        $p[$name].Tag = $Entry.Id
        $p[$name].Add_Checked($filter)
        $p[$name].Add_Unchecked($filter)
    }
    $p['AppsSearchBox'].Tag = $Entry.Id
    $p['AppsSearchBox'].Add_TextChanged($filter)

    $selection = {
        param($control)
        Invoke-MwpUiSafe -Name 'UI.Apps.Selection' -Action {
            $entry = $script:MwpUi.Instances[[string]$control.Tag]
            if ($null -ne $entry) {
                Update-MwpAppsView -Entry $entry -Selection
            }
        }
    }
    foreach ($name in 'AppsGrid', 'UpgradesGrid', 'SearchGrid', 'AppsUndoGrid') {
        $p[$name].Tag = $Entry.Id
        $p[$name].Add_SelectionChanged($selection)
    }
    Start-MwpUiAppsRefresh -Entry $Entry
}
