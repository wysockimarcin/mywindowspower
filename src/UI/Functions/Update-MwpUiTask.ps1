function Update-MwpUiTask {
    <#
    .SYNOPSIS
        Obsługuje zakończone zadania GUI w wątku okna i zwraca podsumowanie trwających zadań.

    .DESCRIPTION
        Wywoływana cyklicznie przez DispatcherTimer okna (wątek UI), więc OnCompleted może
        bezpiecznie zmieniać kontrolki (D-039). Dla zadania skryptu odbiera wyjście (EndInvoke),
        ostrzeżenia i błędy nieprzerywające (Warnings) oraz błąd przerywający (Error, status Failed);
        zadanie przerwane po anulowaniu ma status Cancelled. Dla operacji MWP.Remote odbiera wynik
        przez Wait-MwpOperation (także po przekroczeniu limitu czasu). Zakończone zadanie znika
        z rejestru; błąd w OnCompleted trafia do pola Error zadania i nie przerywa obsługi innych.
        Zwraca: Completed (zadania zakończone w tym wywołaniu), Running, Percent (-1 = nieokreślony),
        Message, CanCancel.

    .PARAMETER Registry
        Lista zadań okna.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Odbiera wyniki zadań w pamięci procesu; nie zmienia stanu systemu.')]
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [Collections.Generic.List[object]] $Registry
    )

    $completed = New-Object -TypeName System.Collections.Generic.List[object]
    foreach ($task in @($Registry.ToArray())) {
        $done = $false
        if ($task.Kind -eq 'Operation') {
            $operation = $task.Operation
            $expired = (Get-Date) -ge $operation.StartedAt.AddSeconds($operation.TimeoutSeconds)
            if ($operation.Status -ne 'Running' -or $null -eq $operation.AsyncResult -or $operation.AsyncResult.IsCompleted -or $expired) {
                $result = Wait-MwpOperation -Operation $operation -WaitSeconds 0
                if ($null -ne $result) {
                    $task.Output = @($result)
                    $task.Status = switch ($operation.Status) {
                        'Completed' { 'Completed' }
                        'Cancelled' { 'Cancelled' }
                        default { 'Failed' }
                    }
                    if ($task.Status -eq 'Failed') {
                        $task.Error = $result.Message
                    }
                    $done = $true
                }
            }
        }
        elseif ($task.AsyncResult.IsCompleted) {
            $powerShell = $task.PowerShell
            try {
                $task.Output = @($powerShell.EndInvoke($task.AsyncResult))
                $task.Status = 'Completed'
            }
            catch {
                $exception = $_.Exception
                while ($exception -is [Management.Automation.MethodInvocationException] -and $null -ne $exception.InnerException) {
                    $exception = $exception.InnerException
                }
                if ($task.Progress.CancelRequested -or $exception -is [Management.Automation.PipelineStoppedException]) {
                    $task.Status = 'Cancelled'
                }
                else {
                    $task.Status = 'Failed'
                    $task.Error = $exception.Message
                }
            }
            if ($task.Status -eq 'Completed' -and $task.Progress.CancelRequested -and $powerShell.InvocationStateInfo.State -eq 'Stopped') {
                $task.Status = 'Cancelled'
            }
            $task.Warnings = @(@($powerShell.Streams.Warning | ForEach-Object { $_.Message }) + @($powerShell.Streams.Error | ForEach-Object { $_.ToString() }))
            $powerShell.Dispose()
            $task.PowerShell = $null
            $task.AsyncResult = $null
            $done = $true
        }

        if ($done) {
            $task.CompletedAt = Get-Date
            $null = $Registry.Remove($task)
            if ($null -ne $task.OnCompleted) {
                try {
                    & $task.OnCompleted $task
                }
                catch {
                    $message = "Błąd obsługi wyniku zadania '{0}': {1}" -f $task.Name, $_.Exception.Message
                    $task.Error = $(if ($task.Error) { '{0} {1}' -f $task.Error, $message } else { $message })
                    Write-Warning $message
                }
            }
            $completed.Add($task)
        }
    }

    $running = @($Registry.ToArray())
    $percent = -1
    $message = ''
    if ($running.Count -eq 1) {
        $percent = [int]$running[0].Progress.Percent
        $message = '{0}{1}' -f $running[0].Name, $(if ($running[0].Progress.Message) { ': ' + $running[0].Progress.Message } else { '' })
    }
    elseif ($running.Count -gt 1) {
        $message = 'Zadania w tle: {0}' -f (@($running | ForEach-Object { $_.Name }) -join ', ')
    }
    [pscustomobject]@{
        Completed = $completed.ToArray()
        Running   = $running.Count
        Percent   = $percent
        Message   = $message
        CanCancel = @($running | Where-Object { $_.Cancellable }).Count -gt 0
    }
}
