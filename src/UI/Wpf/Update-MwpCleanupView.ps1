function Update-MwpCleanupView {
    <#
    .SYNOPSIS
        Odświeża widok Czyszczenie dysku: nagłówek i ostrzeżenia, tabela kategorii, szczegóły, raport, analiza DISM, postęp i dostępność przycisków.

    .DESCRIPTION
        Z -StateOnly (zegar okna) zmienia tylko panel postępu i dostępność przycisków, z -Selection —
        szczegóły i tekst zaznaczenia. Zaznaczenie kategorii zostaje po odświeżeniu (po Id).
        Dostępność: Get-MwpCleanupActionState.

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
    $view = $Entry.Cleanup
    $scan = $view.Scan
    $context = $Entry.Instance.Context
    $running = $null -ne $view.Task
    $connected = -not (Get-MwpConnectionStateInfo -Context $context).NeedsCredential
    $grid = $p['CleanupGrid']

    if (-not $StateOnly -and -not $Selection) {
        $parts = New-Object -TypeName System.Collections.Generic.List[string]
        $parts.Add(('Komputer {0}' -f $context.ComputerName))
        if ($running -and $view.TaskKind -eq 'Scan') {
            $parts.Add('skanowanie…')
        }
        elseif ($null -ne $scan) {
            $parts.Add(('skan {0}: do zwolnienia {1} ({2} plików)' -f ([datetime]$scan.CollectedAt).ToString('HH:mm:ss'), $scan.TotalText, $scan.TotalFiles))
            $parts.Add($(if ($scan.IncludeUserProfiles) { 'profile: wszystkie' } elseif ($scan.IsRemote) { 'profile: nie (tylko lokalizacje systemowe)' } else { 'profil: bieżące konto' }))
        }
        $p['CleanupStatusText'].Text = $parts -join ' · '

        $warnings = New-Object -TypeName System.Collections.Generic.List[string]
        if ($view.ScanError) {
            $warnings.Add([string]$view.ScanError)
        }
        if ($null -ne $scan) {
            foreach ($warning in @($scan.Warnings)) {
                $warnings.Add([string]$warning)
            }
        }
        $p['CleanupWarningText'].Text = $warnings -join [Environment]::NewLine
        $p['CleanupWarningBanner'].Visibility = $(if ($warnings.Count -gt 0) { 'Visible' } else { 'Collapsed' })

        $selectedIds = @(@($grid.SelectedItems) | ForEach-Object { [string]$_.Id })
        $rows = @(Get-MwpCleanupRow -Scan $scan)
        $grid.ItemsSource = $rows
        foreach ($row in $rows) {
            if ($selectedIds -contains [string]$row.Id) {
                $null = $grid.SelectedItems.Add($row)
            }
        }

        $p['CleanupReportText'].Text = $(if ($null -ne $view.Report) { [string]$view.Report.Text } else { 'Brak — raport pojawi się po czyszczeniu.' })
        $p['ComponentStoreText'].Text = if ($view.StoreLoading) {
            'Analiza w toku (DISM może pracować kilka minut; postęp i „Anuluj” na pasku stanu)…'
        }
        elseif ($view.StoreError) {
            [string]$view.StoreError
        }
        else {
            (Get-MwpCleanupDetail -Analysis $view.Store).Text
        }
        $Selection = $true
    }

    $selectedIds = @(@($grid.SelectedItems) | ForEach-Object { [string]$_.Id })
    if ($Selection) {
        if ($selectedIds.Count -gt 1) {
            $p['CleanupDetailTitle'].Text = 'Zaznaczono {0} kategorii.' -f $selectedIds.Count
            $p['CleanupDetailText'].Text = ''
        }
        else {
            $category = if ($selectedIds.Count -eq 1 -and $view.CategoryById.ContainsKey($selectedIds[0])) { $view.CategoryById[$selectedIds[0]] } else { $null }
            $detail = Get-MwpCleanupDetail -Category $category
            $p['CleanupDetailTitle'].Text = $detail.Title
            $p['CleanupDetailText'].Text = $detail.Text
        }
    }

    # Postęp zadania widoku (skan albo czyszczenie).
    if ($running) {
        $progress = $view.Task.Progress
        $percent = [int]$progress['Percent']
        $label = if ($view.TaskKind -eq 'Scan') { 'Skanowanie' } else { 'Czyszczenie' }
        $p['CleanupProgressPanel'].Visibility = 'Visible'
        $p['CleanupProgressBar'].IsIndeterminate = $percent -lt 0
        $p['CleanupProgressBar'].Value = [Math]::Max(0, $percent)
        $p['CleanupProgressText'].Text = '{0}{1}{2}' -f $label, $(if ($progress['Message']) { ': ' + $progress['Message'] } else { '…' }),
        $(if ($progress['CancelRequested']) { ' — anulowanie (po bieżącym pliku lub kategorii)…' } else { '' })
        $p['CleanupCancelButton'].IsEnabled = -not [bool]$progress['CancelRequested']
    }
    else {
        $p['CleanupProgressPanel'].Visibility = 'Collapsed'
    }

    $ready = $connected -and -not $running -and $Entry.Busy -eq 0
    $state = Get-MwpCleanupActionState -Scan $scan -SelectedId $selectedIds -Ready $ready
    $p['CleanupScanButton'].IsEnabled = $state.CanScan
    $p['CleanupRunButton'].IsEnabled = $state.CanRun
    $p['CleanupSelectAllButton'].IsEnabled = $state.CanSelectAll
    $p['CleanupProfilesCheck'].IsEnabled = $ready
    $p['CleanupSelectionText'].Text = $state.SelectionText
    $p['ComponentStoreButton'].IsEnabled = $connected -and -not $view.StoreLoading
}
