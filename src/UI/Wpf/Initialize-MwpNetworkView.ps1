function Initialize-MwpNetworkView {
    <#
    .SYNOPSIS
        Podpina widok sieci (Views\Network.xaml) w instancji modułu Network i uruchamia pierwszy odczyt stanu w tle.

    .DESCRIPTION
        Stan widoku jest w wpisie instancji ($Entry.Network), więc dwie instancje (np. localhost
        i komputer zdalny) mają niezależne widoki, zadania i wyniki. Przyciski mają w Tag identyfikator
        instancji, a jedna obsługa (Invoke-MwpNetworkViewAction) rozpoznaje akcję po nazwie kontrolki.
        Testy łączności startują dopiero przyciskiem. Widok nie wywołuje poleceń systemowych — tylko
        funkcje MWP.Network i MWP.Core (D-015, D-044, D-049).
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '',
        Justification = 'Parametry obsługi zdarzeń WPF są używane w zagnieżdżonych blokach (Invoke-MwpUiSafe -Action), czego reguła nie widzi.')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable] $Entry
    )

    $p = $Entry.ModuleView.Controls
    $Entry.Network = @{
        Status         = $null
        StatusError    = $null
        StatusLoading  = $false
        StatusReadAt   = $null
        Test           = $null
        TestError      = $null
        TestLoading    = $false
        ExpiredRefresh = $false
        PendingKey     = ''
    }
    $handler = {
        param($control)
        Invoke-MwpUiSafe -Name ('UI.Network.' + $control.Name) -Action {
            $entry = $script:MwpUi.Instances[[string]$control.Tag]
            if ($null -ne $entry) {
                Invoke-MwpNetworkViewAction -Entry $entry -Action $control.Name -Owner (Get-MwpOwnerWindow -Element $control)
            }
        }
    }
    foreach ($name in 'NetworkRefreshButton', 'NetworkApproveButton', 'NetworkEnableButton', 'NetworkDisableButton', 'NetworkRenewButton',
        'NetworkDnsButton', 'NetworkFlushButton', 'NetworkTestButton', 'NetworkWinsockButton', 'NetworkIpResetButton', 'NetworkUndoButton') {
        $p[$name].Tag = $Entry.Id
        $p[$name].Add_Click($handler)
    }
    $p['NetworkDnsPresetBox'].ItemsSource = @(Get-MwpNetworkViewOption -Kind DnsPreset)
    $p['NetworkDnsPresetBox'].SelectedIndex = 1
    $p['NetworkRollbackBox'].ItemsSource = @(Get-MwpNetworkViewOption -Kind Rollback)
    $p['NetworkRollbackBox'].SelectedIndex = 1

    $refresh = {
        param($control)
        Invoke-MwpUiSafe -Name 'UI.Network.Selection' -Action {
            $entry = $script:MwpUi.Instances[[string]$control.Tag]
            if ($null -ne $entry) {
                Update-MwpNetworkView -Entry $entry -Selection
            }
        }
    }
    foreach ($name in 'NetworkAdaptersGrid', 'NetworkUndoGrid', 'NetworkDnsPresetBox') {
        $p[$name].Tag = $Entry.Id
        $p[$name].Add_SelectionChanged($refresh)
    }
    Start-MwpUiNetworkRefresh -Entry $Entry
}
