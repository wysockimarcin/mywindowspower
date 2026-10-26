function Close-MwpUiInstance {
    <#
    .SYNOPSIS
        Zamyka jedną instancję modułu i jej widok; pozostałe instancje (także tego samego modułu) działają dalej.

    .DESCRIPTION
        Anuluje zadania GUI tej instancji, wywołuje Close-MwpModuleInstance (anulowanie operacji,
        zamknięcie sesji, poświadczenia usunięte z pamięci), zamyka osobne okno i usuwa widok
        (D-035). Gdy instancja była pokazana w oknie głównym, host przechodzi do widoku obszaru.

    .PARAMETER Id
        Identyfikator instancji.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Id
    )

    $ui = $script:MwpUi
    $entry = $ui.Instances[$Id]
    if ($null -eq $entry) {
        return
    }
    foreach ($task in @($ui.Tasks.ToArray())) {
        $owner = $task.State
        if ($owner -is [hashtable]) {
            $owner = $owner['InstanceId']
        }
        if ([string]$owner -eq $Id) {
            Stop-MwpUiTask -Task $task -Confirm:$false
        }
    }
    $null = $ui.Instances.Remove($Id)
    $result = Close-MwpModuleInstance -Instance $entry.Instance
    if ($null -ne $entry.Window) {
        $entry.Reattaching = $true
        $entry.WindowHost.Content = $null
        $entry.Window.Close()
        $entry.Window = $null
    }
    if ($ui.Controls['ViewHost'].Content -eq $entry.View.Root) {
        $ui.Controls['ViewHost'].Content = $null
    }
    Update-MwpNavigation
    if ($ui.CurrentKey -eq ('instance:' + $Id)) {
        Show-MwpView -Key ('area:' + $entry.Instance.ModuleId)
    }
    else {
        Update-MwpCurrentView
    }
    if (-not $result.Success) {
        Show-MwpMessage -Text $result.Message -Kind Warning
    }
}
