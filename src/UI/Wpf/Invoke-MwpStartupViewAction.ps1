function Invoke-MwpStartupViewAction {
    <#
    .SYNOPSIS
        Obsługa przycisków widoku Autostart i harmonogram: odczyt, włącz/wyłącz pozycję, włącz/wyłącz/uruchom/usuń zadanie, cofnięcie.

    .DESCRIPTION
        Zmiany idą przez Invoke-MwpUiInstanceChange z krokami — funkcjami MWP.Startup z kontekstem
        instancji (podgląd w tle → okno potwierdzenia z komputerem docelowym → wykonanie w tle,
        D-044, D-046). Usunięcie zadania jest operacją destrukcyjną: okno potwierdzenia wymaga
        wpisania nazwy zadania, a funkcja logiki eksportuje XML przed usunięciem. Cofnięcie
        wywołuje Invoke-MwpUndo z kontekstem tej instancji.

    .PARAMETER Action
        Nazwa przycisku (x:Name) z Views\Startup.xaml.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Zmiany przechodzą przez podgląd i okno potwierdzenia (Invoke-MwpUiInstanceChange).')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable] $Entry,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Action,

        [AllowNull()]
        [object] $Owner
    )

    $p = $Entry.ModuleView.Controls
    $view = $Entry.Startup
    $itemRow = $p['ItemsGrid'].SelectedItem
    $item = if ($null -ne $itemRow -and $view.ItemById.ContainsKey([string]$itemRow.Id)) { $view.ItemById[[string]$itemRow.Id] } else { $null }
    $taskRow = $p['TasksGrid'].SelectedItem
    $task = if ($null -ne $taskRow -and $view.TaskByPath.ContainsKey([string]$taskRow.Path)) { $view.TaskByPath[[string]$taskRow.Path] } else { $null }
    $after = 'Start-MwpUiStartupRefresh'

    switch ($Action) {
        'StartupRefreshButton' {
            Start-MwpUiStartupRefresh -Entry $Entry
        }
        { $_ -in 'EnableItemButton', 'DisableItemButton' } {
            if ($null -eq $item) { return }
            $enabled = $Action -eq 'EnableItemButton'
            Invoke-MwpUiInstanceChange -Entry $Entry -Header $(if ($enabled) { 'Włączenie pozycji autostartu' } else { 'Wyłączenie pozycji autostartu' }) `
                -Target ("Autostart '{0}' ({1}, {2})" -f $item.Name, $item.LocationText, $item.UserName) -AfterCommand $after -Owner $Owner `
                -Steps @(@{ Command = 'Set-MwpStartupItemState'; Parameters = @{ Id = $item.Id; Enabled = $enabled }; Label = $(if ($enabled) { 'Włączenie' } else { 'Wyłączenie' }) })
        }
        { $_ -in 'EnableTaskButton', 'DisableTaskButton' } {
            if ($null -eq $task) { return }
            $enabled = $Action -eq 'EnableTaskButton'
            Invoke-MwpUiInstanceChange -Entry $Entry -Header $(if ($enabled) { 'Włączenie zadania harmonogramu' } else { 'Wyłączenie zadania harmonogramu' }) `
                -Target ("Zadanie '{0}'" -f $task.Path) -AfterCommand $after -Owner $Owner `
                -Steps @(@{ Command = 'Set-MwpScheduledTaskState'; Parameters = @{ TaskPath = $task.TaskPath; TaskName = $task.TaskName; Enabled = $enabled }; Label = $(if ($enabled) { 'Włączenie' } else { 'Wyłączenie' }) })
        }
        'RunTaskButton' {
            if ($null -eq $task) { return }
            Invoke-MwpUiInstanceChange -Entry $Entry -Header 'Uruchomienie zadania harmonogramu' -Target ("Zadanie '{0}'" -f $task.Path) -AfterCommand $after -Owner $Owner `
                -Steps @(@{ Command = 'Start-MwpScheduledTask'; Parameters = @{ TaskPath = $task.TaskPath; TaskName = $task.TaskName }; Label = 'Uruchomienie' })
        }
        'RemoveTaskButton' {
            if ($null -eq $task) { return }
            Invoke-MwpUiInstanceChange -Entry $Entry -Header 'Usunięcie zadania harmonogramu' -Class Destructive -RequireText $task.TaskName `
                -Target ("Zadanie '{0}' (definicja zostanie zapisana jako XML przed usunięciem)" -f $task.Path) -AfterCommand $after -Owner $Owner `
                -Steps @(@{ Command = 'Remove-MwpScheduledTask'; Parameters = @{ TaskPath = $task.TaskPath; TaskName = $task.TaskName }; Label = 'Usunięcie' })
        }
        'StartupUndoButton' {
            $undo = $p['StartupUndoGrid'].SelectedItem
            if ($null -eq $undo) { return }
            Invoke-MwpUiInstanceChange -Entry $Entry -Header 'Cofnięcie zmiany autostartu lub harmonogramu' -Target $undo.Description -AfterCommand $after -Owner $Owner `
                -Steps @(@{ Command = 'Invoke-MwpUndo'; Parameters = @{ Id = $undo.Id }; Label = 'Cofnięcie' })
        }
    }
}
