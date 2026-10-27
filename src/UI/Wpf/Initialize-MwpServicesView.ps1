function Initialize-MwpServicesView {
    <#
    .SYNOPSIS
        Podpina widok Usługi (Views\Services.xaml) w instancji modułu Services i uruchamia pierwszy odczyt usług w tle.

    .DESCRIPTION
        Stan widoku jest w wpisie instancji ($Entry.Services), więc dwie instancje (np. localhost
        i komputer zdalny) mają niezależne widoki. Przyciski mają w Tag identyfikator instancji,
        a jedna obsługa (Invoke-MwpServicesViewAction) rozpoznaje akcję po nazwie przycisku. Widok
        nie wywołuje poleceń systemowych — tylko funkcje MWP.Services i MWP.Core (D-015, D-044, D-045).
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '',
        Justification = 'Parametry obsługi zdarzeń WPF są używane w zagnieżdżonych blokach (Invoke-MwpUiSafe -Action), czego reguła nie widzi.')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable] $Entry
    )

    $p = $Entry.ModuleView.Controls
    $Entry.Services = @{
        List    = $null
        ByName  = @{}
        Loading = $false
        Error   = $null
        Profile = $null
        Diff    = @()
    }
    $buttons = @('ServicesRefreshButton', 'StartServiceButton', 'StopServiceButton', 'RestartServiceButton', 'SetStartupTypeButton',
        'ExportProfileButton', 'LoadProfileButton', 'ApplySelectedProfileButton', 'ApplyProfileButton', 'ServicesUndoButton')
    $handler = {
        param($control)
        Invoke-MwpUiSafe -Name ('UI.Services.' + $control.Name) -Action {
            $entry = $script:MwpUi.Instances[[string]$control.Tag]
            if ($null -ne $entry) {
                Invoke-MwpServicesViewAction -Entry $entry -Action $control.Name -Owner (Get-MwpOwnerWindow -Element $control)
            }
        }
    }
    foreach ($name in $buttons) {
        $p[$name].Tag = $Entry.Id
        $p[$name].Add_Click($handler)
    }

    # Filtry: zmiana odświeża tylko listę (bez ponownego odczytu z komputera).
    $p['ServiceStatusFilter'].ItemsSource = @(Get-MwpServiceViewOption -Kind StatusFilter)
    $p['ServiceStatusFilter'].SelectedIndex = 0
    $p['ServiceTypeFilter'].ItemsSource = @(Get-MwpServiceViewOption -Kind StartupTypeFilter)
    $p['ServiceTypeFilter'].SelectedIndex = 0
    $filter = {
        param($control)
        Invoke-MwpUiSafe -Name 'UI.Services.Filter' -Action {
            $entry = $script:MwpUi.Instances[[string]$control.Tag]
            if ($null -ne $entry) {
                Update-MwpServicesView -Entry $entry -Filter
            }
        }
    }
    foreach ($name in 'ServiceStatusFilter', 'ServiceTypeFilter') {
        $p[$name].Tag = $Entry.Id
        $p[$name].Add_SelectionChanged($filter)
    }
    $p['ServiceSearchBox'].Tag = $Entry.Id
    $p['ServiceSearchBox'].Add_TextChanged($filter)
    $p['ServiceProtectedFilter'].Tag = $Entry.Id
    $p['ServiceProtectedFilter'].Add_Click($filter)

    # Wybór usługi: szczegóły, lista typów uruchomienia i przyciski.
    $selection = {
        param($control)
        Invoke-MwpUiSafe -Name 'UI.Services.Selection' -Action {
            $entry = $script:MwpUi.Instances[[string]$control.Tag]
            if ($null -ne $entry) {
                Update-MwpServicesView -Entry $entry -Selection
            }
        }
    }
    $p['ServicesGrid'].Tag = $Entry.Id
    $p['ServicesGrid'].Add_SelectionChanged($selection)
    $state = {
        param($control)
        Invoke-MwpUiSafe -Name 'UI.Services.State' -Action {
            $entry = $script:MwpUi.Instances[[string]$control.Tag]
            if ($null -ne $entry) {
                Update-MwpServicesView -Entry $entry -StateOnly
            }
        }
    }
    foreach ($name in 'StartupTypeBox', 'ProfileGrid', 'ServicesUndoGrid') {
        $p[$name].Tag = $Entry.Id
        $p[$name].Add_SelectionChanged($state)
    }

    # Lista ochronna (plik danych MWP.Core i opcjonalne rozszerzenie lokalne) — tylko do przeglądu.
    $p['ShowProtectedCheck'].Tag = $Entry.Id
    $p['ShowProtectedCheck'].Add_Click({
            param($control)
            $entry = $script:MwpUi.Instances[[string]$control.Tag]
            if ($null -ne $entry) {
                $entry.ModuleView.Controls['ProtectedPanel'].Visibility = $(if ($control.IsChecked) { 'Visible' } else { 'Collapsed' })
            }
        })
    try {
        $p['ProtectedGrid'].ItemsSource = @(Get-MwpProtectedItem -Category Service | Sort-Object -Property Name | ForEach-Object {
                [pscustomobject]@{ Name = $_.Name; Reason = $_.Reason; SourceText = $(if ($_.Source -eq 'Local') { 'lokalna' } else { 'wbudowana' }) }
            })
    }
    catch {
        $Entry.Services.Error = 'Nie można odczytać listy ochronnej: {0}' -f $_.Exception.Message
    }
    Start-MwpUiServicesRefresh -Entry $Entry
}
