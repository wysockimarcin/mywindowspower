function Update-MwpStartupView {
    <#
    .SYNOPSIS
        Odświeża widok Autostart i harmonogram: nagłówek i ostrzeżenia, listy z filtrami, szczegóły wybranej pozycji i zadania, cofnięcia, dostępność przycisków.

    .DESCRIPTION
        Z -StateOnly (zegar okna) zmienia tylko dostępność przycisków. Z -Filter przelicza listy
        (filtry, bez ponownego odczytu), z -Selection — panele szczegółów. Zaznaczenie zostaje po
        odświeżeniu (po Id pozycji i ścieżce zadania). Blokady: Get-MwpStartupActionState (D-046).

    .PARAMETER StateOnly
        Tylko przyciski.

    .PARAMETER Filter
        Listy po zmianie filtrów.

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

        [switch] $Filter,

        [switch] $Selection
    )

    $p = $Entry.ModuleView.Controls
    $view = $Entry.Startup
    $items = $view.Items
    $tasks = $view.Tasks
    $context = $Entry.Instance.Context
    $loading = $view.ItemsLoading -or $view.TasksLoading
    $busy = $Entry.Busy -gt 0 -or $loading
    $connected = -not (Get-MwpConnectionStateInfo -Context $context).NeedsCredential

    $selectedItem = {
        $row = $p['ItemsGrid'].SelectedItem
        if ($null -ne $row -and $view.ItemById.ContainsKey([string]$row.Id)) { $view.ItemById[[string]$row.Id] } else { $null }
    }
    $selectedTask = {
        $row = $p['TasksGrid'].SelectedItem
        if ($null -ne $row -and $view.TaskByPath.ContainsKey([string]$row.Path)) { $view.TaskByPath[[string]$row.Path] } else { $null }
    }
    $time = { param($Value) try { ([datetime]$Value).ToString('HH:mm:ss') } catch { [string]$Value } }

    if ($Filter -or (-not $StateOnly -and -not $Selection)) {
        $parts = New-Object -TypeName System.Collections.Generic.List[string]
        $parts.Add(('Komputer {0}' -f (Format-MwpTargetLabel -Context $context)))
        if ($view.ItemsLoading) { $parts.Add('odczyt autostartu…') } elseif ($null -ne $items) { $parts.Add(('{0} pozycji autostartu ({1})' -f @($items.Items).Count, (& $time $items.CollectedAt))) }
        if ($view.TasksLoading) { $parts.Add('odczyt harmonogramu…') } elseif ($null -ne $tasks) { $parts.Add(('{0} zadań ({1})' -f @($tasks.Tasks).Count, (& $time $tasks.CollectedAt))) }
        $p['StartupStatusText'].Text = $parts -join ' · '

        if ($null -ne $items) {
            $scope = $p['ItemScopeFilter'].SelectedItem
            $state = $p['ItemStateFilter'].SelectedItem
            $risk = $p['ItemRiskFilter'].SelectedItem
            $selectedId = if ($null -ne $p['ItemsGrid'].SelectedItem) { [string]$p['ItemsGrid'].SelectedItem.Id } else { $null }
            $rows = @(Select-MwpStartupItem -Item @($items.Items) -Scope $(if ($null -ne $scope) { $scope.Value } else { 'All' }) `
                    -State $(if ($null -ne $state) { $state.Value } else { 'All' }) -Risk $(if ($null -ne $risk) { $risk.Value } else { 'All' }) -Search $p['ItemSearchBox'].Text | ForEach-Object {
                    [pscustomobject]@{
                        Id           = $_.Id
                        Name         = $_.Name
                        StateText    = $_.StateText
                        RiskText     = $_.RiskText
                        Publisher    = $_.Publisher
                        LocationText = $_.LocationText
                        UserName     = $_.UserName
                    }
                })
            $p['ItemsGrid'].ItemsSource = $rows
            $p['ItemCountText'].Text = 'Pokazano {0} z {1}' -f $rows.Count, @($items.Items).Count
            if ($selectedId) {
                $p['ItemsGrid'].SelectedItem = @($rows | Where-Object { $_.Id -eq $selectedId }) | Select-Object -First 1
            }
        }
        if ($null -ne $tasks) {
            $taskState = $p['TaskStateFilter'].SelectedItem
            $selectedPath = if ($null -ne $p['TasksGrid'].SelectedItem) { [string]$p['TasksGrid'].SelectedItem.Path } else { $null }
            $lock = [string][char]0xE72E   # kłódka w czcionce ikon (Mwp.Font.Icons)
            $rows = @(Select-MwpScheduledTask -Task @($tasks.Tasks) -State $(if ($null -ne $taskState) { $taskState.Value } else { 'All' }) `
                    -HideMicrosoft:([bool]$p['TaskHideMicrosoftCheck'].IsChecked) -ProtectedOnly:([bool]$p['TaskProtectedFilter'].IsChecked) -Search $p['TaskSearchBox'].Text | ForEach-Object {
                    [pscustomobject]@{
                        Lock        = $(if ($_.IsProtected) { $lock } else { '' })
                        Path        = $_.Path
                        StateText   = $_.StateText
                        TriggerText = $_.TriggerText
                        LastRun     = $(if ($null -ne $_.LastRunTime) { $_.LastRunTime.ToString('yyyy-MM-dd HH:mm') } else { '' })
                        RiskText    = $_.RiskText
                        Publisher   = $_.Publisher
                    }
                })
            $p['TasksGrid'].ItemsSource = $rows
            $p['TaskCountText'].Text = 'Pokazano {0} z {1}' -f $rows.Count, @($tasks.Tasks).Count
            if ($selectedPath) {
                $p['TasksGrid'].SelectedItem = @($rows | Where-Object { $_.Path -eq $selectedPath }) | Select-Object -First 1
            }
        }
        $Selection = $true
    }

    if (-not $StateOnly -and -not $Filter -and -not $Selection) {
        return
    }
    $item = & $selectedItem
    $task = & $selectedTask
    if ($Selection) {
        $detail = Get-MwpStartupDetail -Item $item
        $p['ItemDetailTitle'].Text = $detail.Title
        $p['ItemDetailText'].Text = $detail.Text
        $detail = Get-MwpStartupDetail -Task $task
        $p['TaskDetailTitle'].Text = $detail.Title
        $p['TaskDetailText'].Text = $detail.Text
    }

    if (-not $StateOnly) {
        # Ostrzeżenia i cofnięcia (poza zegarem okna).
        $warnings = New-Object -TypeName System.Collections.Generic.List[string]
        foreach ($text in @($view.ItemsError, $view.TasksError)) {
            if ($text) { $warnings.Add([string]$text) }
        }
        foreach ($list in @($items, $tasks)) {
            if ($null -ne $list) {
                foreach ($warning in @($list.Warnings)) {
                    $warnings.Add([string]$warning)
                }
            }
        }
        if (($null -ne $items -and $false -eq $items.IsAdministrator) -or ($null -ne $tasks -and $false -eq $tasks.IsAdministrator)) {
            $warnings.Add('Brak uprawnień administratora na tym komputerze: zmiany pozycji wszystkich użytkowników i zadań harmonogramu są niedostępne, a harmonogram pokazuje tylko część zadań (uruchom aplikację jako administrator albo połącz się kontem administratora).')
        }
        $p['StartupWarningText'].Text = $warnings -join [Environment]::NewLine
        $p['StartupWarningBanner'].Visibility = $(if ($warnings.Count -gt 0) { 'Visible' } else { 'Collapsed' })
        $undoRows = @(Get-MwpUndoEntry -ComputerName $context.ComputerName -Status Pending | Where-Object { $_.Module -eq 'MWP.Startup' } |
                Sort-Object -Property CreatedAt -Descending | Select-Object -First 50 | ForEach-Object {
                    [pscustomobject]@{ Id = $_.Id; When = $(if ($_.CreatedAt) { ([datetime]$_.CreatedAt).ToString('yyyy-MM-dd HH:mm') } else { '' }); Description = $_.Description }
                })
        $p['StartupUndoGrid'].ItemsSource = $undoRows
    }

    # Przyciski.
    $itemState = Get-MwpStartupActionState -Item $item -Ready ($connected -and -not $busy -and $null -ne $items) `
        -IsAdministrator ($null -ne $items -and $false -ne $items.IsAdministrator) -CurrentUserSid $(if ($null -ne $items) { $items.CurrentUserSid } else { '' })
    $p['EnableItemButton'].IsEnabled = $itemState.CanEnable
    $p['DisableItemButton'].IsEnabled = $itemState.CanDisable
    $p['ItemNoteText'].Text = [string]$itemState.Note
    $p['ItemNoteBanner'].Visibility = $(if ($itemState.Note) { 'Visible' } else { 'Collapsed' })
    $taskState = Get-MwpStartupActionState -Task $task -Ready ($connected -and -not $busy -and $null -ne $tasks) -IsAdministrator ($null -ne $tasks -and $false -ne $tasks.IsAdministrator)
    $p['EnableTaskButton'].IsEnabled = $taskState.CanEnable
    $p['DisableTaskButton'].IsEnabled = $taskState.CanDisable
    $p['RunTaskButton'].IsEnabled = $taskState.CanRun
    $p['RemoveTaskButton'].IsEnabled = $taskState.CanRemove
    $p['TaskNoteText'].Text = [string]$taskState.Note
    $p['TaskNoteBanner'].Visibility = $(if ($taskState.Note) { 'Visible' } else { 'Collapsed' })
    $p['StartupRefreshButton'].IsEnabled = $connected -and -not $busy
    $p['StartupUndoButton'].IsEnabled = $connected -and -not $busy -and $null -ne $p['StartupUndoGrid'].SelectedItem
}
