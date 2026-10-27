function Set-MwpScheduledTaskState {
    <#
    .SYNOPSIS
        Włącza albo wyłącza zadanie harmonogramu na komputerze docelowym.

    .DESCRIPTION
        Operacja klasy Zmiana (D-027): odczyt zadania, lista ochronna (zadania krytycznego —
        kategoria Task — nie wolno wyłączyć; włączyć wolno, D-046), uprawnienia administratora na
        komputerze docelowym, podgląd (-WhatIf) i potwierdzenie z nazwą komputera. Zmiana:
        Enable-ScheduledTask / Disable-ScheduledTask i ponowny odczyt stanu — niezgodność jest
        błędem. Wpis cofnięcia: poprzedni stan. Wyłączenie nie przerywa działającej instancji.

    .PARAMETER TaskPath
        Folder zadania (np. '\' albo '\Microsoft\Windows\Defrag\').

    .PARAMETER TaskName
        Nazwa zadania (dokładna).

    .PARAMETER Enabled
        $true — włącz, $false — wyłącz.

    .EXAMPLE
        Set-MwpScheduledTaskState -TaskPath '\' -TaskName 'Adobe Acrobat Update Task' -Enabled $false -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string] $TaskPath,

        [Parameter(Mandatory, Position = 1)]
        [string] $TaskName,

        [Parameter(Mandatory, Position = 2)]
        [bool] $Enabled,

        [PSTypeName('MWP.ExecutionContext')]
        [object] $Context = (New-MwpExecutionContext)
    )

    $computerName = $Context.ComputerName
    $operation = 'Startup.SetTaskState'
    $common = @{ Operation = $operation; Target = ($TaskPath + $TaskName); ComputerName = $computerName }
    if (-not (Test-MwpScheduledTaskName -TaskPath $TaskPath -TaskName $TaskName)) {
        return New-MwpResult @common -Success $false -Message ("Niepoprawny folder lub nazwa zadania: '{0}{1}'." -f $TaskPath, $TaskName)
    }
    $wantedText = if ($Enabled) { 'Włączone' } else { 'Wyłączone' }

    $state = Read-MwpScheduledTaskState -Context $Context -Operation $operation -TaskPath $TaskPath -TaskName $TaskName
    if ($null -ne $state.Task -and $state.Task.Enabled -eq $Enabled) {
        return New-MwpResult @common -Success $true -Before $state.Task.StateText -After $state.Task.StateText -Message ("Zadanie '{0}' jest już w stanie: {1}." -f $state.Task.Path, $state.Task.StateText)
    }
    if ($null -ne $state.Task -and -not $Enabled -and $state.Task.IsProtected) {
        return New-MwpResult @common -Success $false -Before $state.Task.StateText -After $wantedText `
            -Message ("Zadanie '{0}' jest na liście ochronnej — nie można go wyłączyć. Powód: {1}" -f $state.Task.Path, $state.Task.ProtectionReason)
    }
    if (-not $state.Success) {
        return $state.Result
    }
    $task = $state.Task

    $target = Format-MwpOperationTarget -Target ("zadanie harmonogramu '{0}'" -f $task.Path) -ComputerName $computerName
    if (-not $PSCmdlet.ShouldProcess($target, ("Stan: '{0}' → '{1}'" -f $task.StateText, $wantedText))) {
        $note = if (-not $Enabled -and $task.State -eq 'Running') { ' Działająca instancja nie zostanie przerwana.' } else { '' }
        return New-MwpResult @common -Success $true -IsPreview -Before $task.StateText -After $wantedText `
            -Message ("Podgląd: zadanie '{0}': {1} → {2}.{3}" -f $task.Path, $task.StateText, $wantedText, $note)
    }

    $control = Invoke-MwpScheduledTaskControl -Context $Context -Operation $operation -TaskPath $TaskPath -TaskName $TaskName -Action $(if ($Enabled) { 'Enable' } else { 'Disable' })
    $actualEnabled = if ($control.State) { $control.State -ne 'Disabled' } else { $null }
    $failure = $null
    if (-not $control.Success) {
        $failure = $control.Message
    }
    elseif ($actualEnabled -ne $Enabled) {
        $failure = 'po zmianie stan zadania to {0}' -f (Get-MwpStartupText -TaskState ([string]$control.State))
    }

    $undoId = $null
    if ($null -ne $actualEnabled -and $actualEnabled -ne $task.Enabled) {
        $actualText = Get-MwpStartupText -TaskState ([string]$control.State)
        $undo = Save-MwpUndoEntry -Module 'MWP.Startup' -Operation $operation -Target $task.Path -ComputerName $computerName `
            -Description ("Zadanie '{0}': {1} → {2}" -f $task.Path, $task.StateText, $actualText) -Before $task.StateText -After $actualText `
            -UndoCommand 'Set-MwpScheduledTaskState' -UndoParameters @{ TaskPath = $TaskPath; TaskName = $TaskName; Enabled = [bool]$task.Enabled }
        $undoId = $undo.Id
    }
    if ($null -ne $failure) {
        $message = "Nie udało się zmienić stanu zadania '{0}' na komputerze '{1}': {2}" -f $task.Path, $computerName, $failure
        Write-MwpLog -Level Error -Source 'MWP.Startup' -Operation $operation -ComputerName $computerName -Message $message -Data @{ Task = $task.Path; Before = $task.State; Wanted = $wantedText; Actual = $control.State }
        return New-MwpResult @common -Success $false -Changed ($null -ne $undoId) -Before $task.StateText -UndoId $undoId -Message $message -ErrorMessage $control.ErrorMessage
    }
    $message = "Zadanie '{0}' na komputerze '{1}': {2} → {3}." -f $task.Path, $computerName, $task.StateText, $wantedText
    Write-MwpLog -Level Info -Source 'MWP.Startup' -Operation $operation -ComputerName $computerName -Message $message -Data @{ Task = $task.Path; Before = $task.State; After = $control.State }
    New-MwpResult @common -Success $true -Changed $true -Before $task.StateText -After $wantedText -UndoId $undoId -Message $message
}
