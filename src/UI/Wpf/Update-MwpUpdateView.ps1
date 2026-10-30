function Update-MwpUpdateView {
    <#
    .SYNOPSIS
        Odświeża widok Windows Update: stan i ostrzeżenia, usługi, oczekujące aktualizacje, szczegóły, postęp instalacji, pauza, kopie z resetu, historia, cofnięcia i dostępność przycisków.

    .DESCRIPTION
        Z -StateOnly (zegar okna, zmiana wyboru na listach) zmienia tylko postęp i dostępność
        przycisków, z -Selection — szczegóły zaznaczonej aktualizacji. Zaznaczenie aktualizacji zostaje
        po odświeżeniu (po UpdateId). Reguły dostępności: Get-MwpUpdateActionState (D-048).

    .PARAMETER StateOnly
        Tylko postęp i przyciski.

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
    $view = $Entry.Update
    $status = $view.Status
    $search = $view.Search
    $context = $Entry.Instance.Context
    $isLocal = $context.Mode -eq 'Local'
    $running = $null -ne $view.Task
    $connected = -not (Get-MwpConnectionStateInfo -Context $context).NeedsCredential
    $grid = $p['UpdatesGrid']

    if (-not $StateOnly -and -not $Selection) {
        $p['UpdateStatusText'].Text = if ($view.StatusLoading) {
            'Odczyt stanu Windows Update komputera {0}…' -f (Format-MwpTargetLabel -Context $context)
        }
        elseif ($null -ne $status) {
            'Komputer {0} · odczyt {1}' -f (Format-MwpTargetLabel -Context $context), $(if ($null -ne $status.CollectedAt) { ([datetime]$status.CollectedAt).ToString('HH:mm:ss') } else { '' })
        }
        else {
            'Brak odczytu stanu Windows Update.'
        }
        $warnings = New-Object -TypeName System.Collections.Generic.List[string]
        foreach ($text in @($view.StatusError, $view.HistoryError)) {
            if ($text) { $warnings.Add([string]$text) }
        }
        if ($null -ne $status) {
            foreach ($warning in @($status.Warnings)) {
                $warnings.Add([string]$warning)
            }
            if ($false -eq $status.IsAdministrator) {
                $warnings.Add('Brak uprawnień administratora na tym komputerze: instalacja, pauza i reset są niedostępne (uruchom aplikację jako administrator albo połącz się kontem administratora).')
            }
        }
        if (-not $isLocal) {
            $warnings.Add('Komputer zdalny: wyszukiwanie, historia, pauza i reset działają zdalnie; instalację wykonuje się w Ustawieniach Windows Update na tamtym komputerze (D-048).')
        }
        $p['UpdateWarningText'].Text = $warnings -join [Environment]::NewLine
        $p['UpdateWarningBanner'].Visibility = $(if ($warnings.Count -gt 0) { 'Visible' } else { 'Collapsed' })

        $summary = Get-MwpUpdateDetail -Status $status
        $p['UpdateRebootText'].Text = $summary.Title
        $p['UpdateSummaryText'].Text = $summary.Text
        $p['UpdateBackupText'].Text = $summary.Backup
        $p['UpdatePauseText'].Text = $(if ($null -ne $status) { $status.PauseText } else { '' })
        $p['UpdateServicesGrid'].ItemsSource = $(if ($null -ne $status) { @($status.Services) } else { @() })

        $p['UpdateSearchText'].Text = if ($view.SearchLoading) {
            'Wyszukiwanie aktualizacji na komputerze {0} (zwykle do kilku minut; „Anuluj” na pasku stanu)…' -f (Format-MwpTargetLabel -Context $context)
        }
        elseif ($view.SearchError) {
            [string]$view.SearchError
        }
        elseif ($null -ne $search) {
            '{0} Wyszukiwanie: {1}.' -f $search.Message, $(if ($null -ne $search.CollectedAt) { ([datetime]$search.CollectedAt).ToString('HH:mm:ss') } else { '' })
        }
        else {
            'Wyszukiwanie łączy się z serwerem aktualizacji i trwa zwykle od kilkunastu sekund do kilku minut; niczego nie pobiera.'
        }
        $selectedIds = @(@($grid.SelectedItems) | ForEach-Object { [string]$_.UpdateId })
        $rows = @(Get-MwpUpdateRow -Search $search)
        $grid.ItemsSource = $rows
        foreach ($row in $rows) {
            if ($selectedIds -contains [string]$row.UpdateId) {
                $null = $grid.SelectedItems.Add($row)
            }
        }
        $p['UpdateInstallReportText'].Text = $(if ($view.Report) { [string]$view.Report } else { 'Brak — wynik pojawi się po instalacji.' })

        $history = $view.History
        $p['UpdateHistoryText'].Text = if ($view.HistoryLoading) { 'Odczyt historii…' } elseif ($null -ne $history) { $history.Message } else { '' }
        $p['UpdateHistoryGrid'].ItemsSource = @(Get-MwpUpdateRow -History $history -FailedOnly:([bool]$p['UpdateHistoryFailedCheck'].IsChecked))

        $undoRows = @(Get-MwpUndoEntry -ComputerName $context.ComputerName -Status Pending | Where-Object { $_.Module -eq 'MWP.Update' } |
                Sort-Object -Property CreatedAt -Descending | Select-Object -First 50 | ForEach-Object {
                    [pscustomobject]@{ Id = $_.Id; When = $(if ($_.CreatedAt) { ([datetime]$_.CreatedAt).ToString('yyyy-MM-dd HH:mm') } else { '' }); Description = $_.Description }
                })
        $p['UpdateUndoGrid'].ItemsSource = $undoRows
        $Selection = $true
    }

    $selectedIds = @(@($grid.SelectedItems) | ForEach-Object { [string]$_.UpdateId })
    if ($Selection) {
        if ($selectedIds.Count -gt 1) {
            $p['UpdateDetailTitle'].Text = 'Zaznaczono {0} aktualizacji.' -f $selectedIds.Count
            $p['UpdateDetailText'].Text = ''
        }
        else {
            $update = if ($selectedIds.Count -eq 1 -and $null -ne $search) { @($search.Updates | Where-Object { $_.UpdateId -eq $selectedIds[0] }) | Select-Object -First 1 } else { $null }
            $detail = Get-MwpUpdateDetail -Update $update
            $p['UpdateDetailTitle'].Text = $detail.Title
            $p['UpdateDetailText'].Text = $detail.Text
        }
    }

    # Postęp instalacji.
    if ($running) {
        $progress = $view.Task.Progress
        $percent = [int]$progress['Percent']
        $p['UpdateProgressPanel'].Visibility = 'Visible'
        $p['UpdateProgressBar'].IsIndeterminate = $percent -lt 0
        $p['UpdateProgressBar'].Value = [Math]::Max(0, $percent)
        $p['UpdateProgressText'].Text = 'Instalacja{0}{1}' -f $(if ($progress['Message']) { ': ' + $progress['Message'] } else { '…' }),
        $(if ($progress['CancelRequested']) { ' — anulowanie po bieżącej aktualizacji…' } else { '' })
        $p['UpdateCancelButton'].IsEnabled = -not [bool]$progress['CancelRequested']
    }
    else {
        $p['UpdateProgressPanel'].Visibility = 'Collapsed'
    }

    $ready = $connected -and -not $running -and $Entry.Busy -eq 0
    $state = Get-MwpUpdateActionState -Status $status -Search $search -SelectedId $selectedIds -IsLocal $isLocal -Ready $ready
    $p['UpdateRefreshButton'].IsEnabled = $connected -and -not $view.StatusLoading
    $p['UpdateSearchButton'].IsEnabled = $ready -and -not $view.SearchLoading
    $p['UpdateTypeBox'].IsEnabled = -not $view.SearchLoading
    $p['UpdateInstallButton'].IsEnabled = $state.CanInstall
    $p['UpdateInstallButton'].ToolTip = $(if ($state.InstallBlocked) { $state.InstallBlocked } else { $null })
    $p['UpdateSettingsButton'].IsEnabled = $state.CanOpenSettings
    $p['UpdateSelectionText'].Text = $state.SelectionText
    $p['UpdatePauseButton'].IsEnabled = $state.CanPause
    $p['UpdateResumeButton'].IsEnabled = $state.CanResume
    $p['UpdateResetButton'].IsEnabled = $state.CanReset
    $p['UpdateHistoryButton'].IsEnabled = $connected -and -not $view.HistoryLoading
    $p['UpdateUndoButton'].IsEnabled = $ready -and $null -ne $p['UpdateUndoGrid'].SelectedItem
}
