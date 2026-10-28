function Update-MwpNetworkView {
    <#
    .SYNOPSIS
        Odświeża widok sieci: stan i ostrzeżenia, zmiany czekające na zatwierdzenie z odliczaniem, adaptery, szczegóły, testy, cofnięcia i dostępność przycisków.

    .DESCRIPTION
        Z -StateOnly (zegar okna co sekundę) zmienia tylko odliczanie i przyciski; z -Selection —
        szczegóły zaznaczonego adaptera i przyciski. Zaznaczenie adaptera zostaje po odświeżeniu (po
        indeksie). 15 s po terminie wycofania widok sam odczytuje stan ponownie, żeby pokazać wynik
        (D-049). Reguły dostępności: Get-MwpNetworkActionState.

    .PARAMETER StateOnly
        Tylko odliczanie i przyciski.

    .PARAMETER Selection
        Szczegóły po zmianie zaznaczenia.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Zmienia tylko kontrolki okna.')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable] $Entry,

        [switch] $StateOnly,

        [switch] $Selection
    )

    $p = $Entry.ModuleView.Controls
    $view = $Entry.Network
    $status = $view.Status
    $context = $Entry.Instance.Context
    $connected = -not (Get-MwpConnectionStateInfo -Context $context).NeedsCredential
    $grid = $p['NetworkAdaptersGrid']

    if (-not $StateOnly -and -not $Selection) {
        $p['NetworkStatusText'].Text = if ($view.StatusLoading) {
            'Odczyt stanu sieci komputera {0}…' -f $context.ComputerName
        }
        elseif ($null -ne $status) {
            'Komputer {0} · {1} adapterów · odczyt {2}' -f $context.ComputerName, @($status.Adapters).Count, $(if ($null -ne $view.StatusReadAt) { ([datetime]$view.StatusReadAt).ToString('HH:mm:ss') } else { '' })
        }
        else {
            'Brak odczytu stanu sieci.'
        }
        $warnings = New-Object -TypeName System.Collections.Generic.List[string]
        if ($view.StatusError) { $warnings.Add([string]$view.StatusError) }
        if ($null -ne $status) {
            foreach ($warning in @($status.Warnings)) { $warnings.Add([string]$warning) }
            if (-not $status.IsAdministrator) {
                $warnings.Add('Brak uprawnień administratora na tym komputerze: odczyt i testy działają, zmiany są niedostępne (uruchom aplikację jako administrator albo połącz się kontem administratora).')
            }
        }
        if ($context.Mode -ne 'Local') {
            $warnings.Add('Komputer zdalny: zmiana DNS albo adaptera może przerwać połączenie. Zmiana czeka na zatwierdzenie — bez niego komputer sam ją wycofa (D-049).')
        }
        $p['NetworkWarningText'].Text = $warnings -join [Environment]::NewLine
        $p['NetworkWarningBanner'].Visibility = $(if ($warnings.Count -gt 0) { 'Visible' } else { 'Collapsed' })

        $selectedIndex = if ($null -ne $grid.SelectedItem) { [int]$grid.SelectedItem.InterfaceIndex } else { 0 }
        $rows = @(Get-MwpNetworkRow -Status $status)
        $grid.ItemsSource = $rows
        $again = @($rows | Where-Object { $_.InterfaceIndex -eq $selectedIndex }) | Select-Object -First 1
        if ($null -eq $again -and $rows.Count -gt 0) {
            $again = $rows[0]
        }
        $grid.SelectedItem = $again

        $p['NetworkTestText'].Text = if ($view.TestLoading) {
            'Testy łączności z komputera {0}…' -f $context.ComputerName
        }
        elseif ($view.TestError) {
            [string]$view.TestError
        }
        elseif ($null -ne $view.Test) {
            '{0} Odczyt: {1}.' -f $view.Test.Summary, $(if ($null -ne $view.Test.CollectedAt) { ([datetime]$view.Test.CollectedAt).ToString('HH:mm:ss') } else { '' })
        }
        else {
            'Ping do bramy i hosta zewnętrznego, rozwiązanie nazwy DNS i opcjonalnie port TCP. Brak odpowiedzi na ping nie zawsze oznacza brak łączności (zapora).'
        }
        $p['NetworkTestGrid'].ItemsSource = @(Get-MwpNetworkRow -Test $view.Test)

        $undoRows = @(Get-MwpUndoEntry -ComputerName $context.ComputerName -Status Pending | Where-Object { $_.Module -eq 'MWP.Network' } |
                Sort-Object -Property CreatedAt -Descending | Select-Object -First 50 | ForEach-Object {
                    [pscustomobject]@{ Id = $_.Id; When = $(if ($_.CreatedAt) { ([datetime]$_.CreatedAt).ToString('yyyy-MM-dd HH:mm') } else { '' }); Description = $_.Description }
                })
        $p['NetworkUndoGrid'].ItemsSource = $undoRows
        $Selection = $true
    }

    # Zmiany czekające na zatwierdzenie: odliczanie co sekundę (zegar okna).
    $pendingGrid = $p['NetworkPendingGrid']
    $pendingRows = @(Get-MwpNetworkRow -Status $status -Pending -ReadAt $view.StatusReadAt)
    $pendingKey = @($pendingRows | ForEach-Object { $_.ChangeId }) -join ','
    if ($pendingKey -ne [string]$view['PendingKey']) {
        # Siatkę podmieniamy tylko przy zmianie listy (zmiana ItemsSource wywołuje SelectionChanged).
        $view['PendingKey'] = $pendingKey
        $pendingGrid.ItemsSource = $pendingRows
        if ($pendingRows.Count -gt 0) {
            $pendingGrid.SelectedIndex = 0
        }
    }
    if ($pendingRows.Count -gt 0) {
        $first = @($pendingRows | Sort-Object -Property RemainingSeconds)[0]
        $p['NetworkPendingText'].Text = if ($first.RemainingSeconds -gt 0) {
            'Zmiana sieci na komputerze {0} czeka na zatwierdzenie: zostało {1} (wycofanie o {2}). Sprawdź, czy połączenie i sieć działają, i zatwierdź.' -f $context.ComputerName, $first.RemainingText, $first.DeadlineText
        }
        else {
            'Termin minął — komputer {0} wycofuje zmianę. Stan zostanie odczytany ponownie.' -f $context.ComputerName
        }
        $p['NetworkPendingPanel'].Visibility = 'Visible'
        if ($first.RemainingSeconds -le -15 -and -not $view.ExpiredRefresh -and -not $view.StatusLoading -and $connected) {
            $view.ExpiredRefresh = $true
            Start-MwpUiNetworkRefresh -Entry $Entry
        }
    }
    else {
        $p['NetworkPendingPanel'].Visibility = 'Collapsed'
    }

    $selectedIndex = if ($null -ne $grid.SelectedItem) { [int]$grid.SelectedItem.InterfaceIndex } else { 0 }
    $ready = $connected -and $Entry.Busy -eq 0 -and -not $view.StatusLoading
    $state = Get-MwpNetworkActionState -Status $status -InterfaceIndex $selectedIndex -Ready $ready
    if ($Selection) {
        $detail = Get-MwpNetworkDetail -Adapter $state.Adapter
        $p['NetworkDetailTitle'].Text = $detail.Title
        $p['NetworkDetailText'].Text = $detail.Text
        $preset = $p['NetworkDnsPresetBox'].SelectedItem
        $p['NetworkDnsCustomBox'].IsEnabled = $null -ne $preset -and $preset.Value -eq 'Custom'
    }
    $p['NetworkActionText'].Text = $state.Hint
    $p['NetworkRefreshButton'].IsEnabled = $connected -and -not $view.StatusLoading
    $p['NetworkApproveButton'].IsEnabled = $state.CanApprove
    $p['NetworkEnableButton'].IsEnabled = $state.CanEnable
    $p['NetworkDisableButton'].IsEnabled = $state.CanDisable
    $p['NetworkRenewButton'].IsEnabled = $state.CanRenew
    $p['NetworkDnsButton'].IsEnabled = $state.CanSetDns
    $p['NetworkFlushButton'].IsEnabled = $state.CanFlush
    $p['NetworkTestButton'].IsEnabled = $state.CanTest -and -not $view.TestLoading
    $p['NetworkWinsockButton'].IsEnabled = $state.CanReset
    $p['NetworkIpResetButton'].IsEnabled = $state.CanReset
    $p['NetworkUndoButton'].IsEnabled = $ready -and $null -ne $p['NetworkUndoGrid'].SelectedItem
}
