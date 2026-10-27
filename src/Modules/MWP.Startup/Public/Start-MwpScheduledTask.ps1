function Start-MwpScheduledTask {
    <#
    .SYNOPSIS
        Uruchamia teraz zadanie harmonogramu na komputerze docelowym.

    .DESCRIPTION
        Operacja klasy Zmiana (D-027) bez wpisu cofnięcia — uruchomienia programu nie da się
        cofnąć (podgląd to mówi). Odczyt zadania, uprawnienia administratora na komputerze
        docelowym, podgląd (-WhatIf) i potwierdzenie z nazwą komputera; zadanie wyłączone albo już
        działające nie jest uruchamiane. Zadanie startuje na komputerze docelowym na koncie
        z definicji zadania (Start-ScheduledTask nie czeka na jego zakończenie).

    .EXAMPLE
        Start-MwpScheduledTask -TaskPath '\' -TaskName 'Adobe Acrobat Update Task' -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string] $TaskPath,

        [Parameter(Mandatory, Position = 1)]
        [string] $TaskName,

        [PSTypeName('MWP.ExecutionContext')]
        [object] $Context = (New-MwpExecutionContext)
    )

    $computerName = $Context.ComputerName
    $operation = 'Startup.StartTask'
    $common = @{ Operation = $operation; Target = ($TaskPath + $TaskName); ComputerName = $computerName }
    if (-not (Test-MwpScheduledTaskName -TaskPath $TaskPath -TaskName $TaskName)) {
        return New-MwpResult @common -Success $false -Message ("Niepoprawny folder lub nazwa zadania: '{0}{1}'." -f $TaskPath, $TaskName)
    }
    $state = Read-MwpScheduledTaskState -Context $Context -Operation $operation -TaskPath $TaskPath -TaskName $TaskName
    if (-not $state.Success) {
        return $state.Result
    }
    $task = $state.Task
    if (-not $task.Enabled) {
        return New-MwpResult @common -Success $false -Before $task.StateText -Message ("Zadanie '{0}' jest wyłączone — włącz je, żeby je uruchomić." -f $task.Path)
    }
    if ($task.State -eq 'Running') {
        return New-MwpResult @common -Success $true -Before $task.StateText -After $task.StateText -Message ("Zadanie '{0}' już działa." -f $task.Path)
    }

    $target = Format-MwpOperationTarget -Target ("zadanie harmonogramu '{0}'" -f $task.Path) -ComputerName $computerName
    if (-not $PSCmdlet.ShouldProcess($target, ('Uruchomienie teraz: {0}' -f $task.ActionText))) {
        return New-MwpResult @common -Success $true -IsPreview -Before $task.StateText -After 'Uruchomione' `
            -Message ("Podgląd: uruchomienie zadania '{0}' ({1}; konto: {2}). Uruchomienia nie da się cofnąć." -f $task.Path, $task.ActionText, $task.Account)
    }

    $control = Invoke-MwpScheduledTaskControl -Context $Context -Operation $operation -TaskPath $TaskPath -TaskName $TaskName -Action Start
    if (-not $control.Success) {
        $message = "Nie udało się uruchomić zadania '{0}' na komputerze '{1}': {2}" -f $task.Path, $computerName, $control.Message
        Write-MwpLog -Level Error -Source 'MWP.Startup' -Operation $operation -ComputerName $computerName -Message $message -Data @{ Task = $task.Path }
        return New-MwpResult @common -Success $false -Before $task.StateText -Message $message -ErrorMessage $control.ErrorMessage
    }
    $afterText = Get-MwpStartupText -TaskState ([string]$control.State)
    $message = "Uruchomiono zadanie '{0}' na komputerze '{1}' (stan: {2})." -f $task.Path, $computerName, $afterText
    Write-MwpLog -Level Info -Source 'MWP.Startup' -Operation $operation -ComputerName $computerName -Message $message -Data @{ Task = $task.Path; After = $control.State }
    New-MwpResult @common -Success $true -Changed $true -Before $task.StateText -After $afterText -Message $message
}
