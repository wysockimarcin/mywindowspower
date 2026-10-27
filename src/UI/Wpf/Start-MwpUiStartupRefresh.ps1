function Start-MwpUiStartupRefresh {
    <#
    .SYNOPSIS
        Odczytuje w tle pozycje autostartu i zadania harmonogramu komputera instancji (dwie operacje) i odświeża widok po zakończeniu każdej.

    .DESCRIPTION
        Operacje w puli MWP.Remote (Get-MwpStartupItem -AsOperation, Get-MwpScheduledTask
        -AsOperation; limit czasu, anulowanie z paska stanu, zamknięcie instancji je anuluje). Błąd
        lub utrata połączenia zmienia tylko ten widok (komunikat), nie aplikację (D-019). Komputer
        zdalny bez poświadczeń: komunikat z prośbą o „Połącz”.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Uruchamia odczyt (bez zmian systemu).')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable] $Entry
    )

    $context = $Entry.Instance.Context
    $view = $Entry.Startup
    if ($view.ItemsLoading -or $view.TasksLoading) {
        return
    }
    if ((Get-MwpConnectionStateInfo -Context $context).NeedsCredential) {
        $view.ItemsError = 'Połącz instancję z komputerem {0} (przycisk „Połącz”), żeby odczytać autostart i harmonogram.' -f $context.ComputerName
        Update-MwpStartupView -Entry $Entry
        return
    }

    $view.ItemsLoading = $true
    $null = Register-MwpUiOperation -Registry $script:MwpUi.Tasks -Operation (Get-MwpStartupItem -Context $context -AsOperation) `
        -Name ('Autostart: odczyt ({0})' -f $context.ComputerName) -State @{ InstanceId = $Entry.Id } -OnCompleted {
        param($Task)
        $entry = $script:MwpUi.Instances[[string]$Task.State.InstanceId]
        if ($null -eq $entry) {
            return
        }
        $entry.Startup.ItemsLoading = $false
        $result = @($Task.Output) | Select-Object -Last 1
        $list = if ($null -ne $result -and $result.Success) { Resolve-MwpStartupItemList -Data $result } else { $null }
        if ($null -ne $list) {
            $entry.Startup.Items = $list
            $byId = @{}
            foreach ($item in @($list.Items)) {
                $byId[$item.Id] = $item
            }
            $entry.Startup.ItemById = $byId
            $entry.Startup.ItemsError = $null
        }
        else {
            $entry.Startup.ItemsError = 'Odczyt autostartu nie powiódł się ({0}): {1}' -f $Task.Status, $(if ($null -ne $result) { $result.Message } else { $Task.Error })
        }
        Update-MwpInstanceView -Entry $entry
    }

    $view.TasksLoading = $true
    $null = Register-MwpUiOperation -Registry $script:MwpUi.Tasks -Operation (Get-MwpScheduledTask -Context $context -AsOperation) `
        -Name ('Harmonogram: odczyt ({0})' -f $context.ComputerName) -State @{ InstanceId = $Entry.Id } -OnCompleted {
        param($Task)
        $entry = $script:MwpUi.Instances[[string]$Task.State.InstanceId]
        if ($null -eq $entry) {
            return
        }
        $entry.Startup.TasksLoading = $false
        $result = @($Task.Output) | Select-Object -Last 1
        $list = if ($null -ne $result -and $result.Success) { Resolve-MwpScheduledTaskList -Data $result } else { $null }
        if ($null -ne $list) {
            $entry.Startup.Tasks = $list
            $byPath = @{}
            foreach ($task in @($list.Tasks)) {
                $byPath[$task.Path] = $task
            }
            $entry.Startup.TaskByPath = $byPath
            $entry.Startup.TasksError = $null
        }
        else {
            $entry.Startup.TasksError = 'Odczyt harmonogramu nie powiódł się ({0}): {1}' -f $Task.Status, $(if ($null -ne $result) { $result.Message } else { $Task.Error })
        }
        Update-MwpInstanceView -Entry $entry
    }
    Update-MwpStartupView -Entry $Entry
}
