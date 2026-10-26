function Start-MwpUiTask {
    <#
    .SYNOPSIS
        Uruchamia zadanie GUI w tle (pula runspace'ów) i rejestruje je do obsługi w wątku okna.

    .DESCRIPTION
        Model (D-039): zadanie w tle nigdy nie dotyka kontrolek WPF. Raportuje postęp przez
        zsynchronizowaną tabelę Progress (Percent 0–100, Message) i sprawdza Progress.CancelRequested.
        Wątek okna co chwilę wywołuje Update-MwpUiTask (DispatcherTimer), który odbiera wynik
        zakończonych zadań i wywołuje OnCompleted w wątku okna — tam wolno aktualizować kontrolki.
        Blok zadania jest odtwarzany z tekstu w runspace puli (bez zmiennych wywołującego): dane
        przekazuje się przez -ArgumentList, a pierwszym parametrem bloku jest tabela Progress:
            { param($Progress, $Path) $Progress.Message = 'Sprawdzanie…'; Test-MwpModulePackage -Path $Path }

    .PARAMETER Registry
        Lista zadań okna (System.Collections.Generic.List[object]).

    .PARAMETER Pool
        Pula z New-MwpUiTaskPool.

    .PARAMETER OnCompleted
        Blok wywoływany w wątku okna po zakończeniu: param($Task); wynik w $Task.Output, błąd
        w $Task.Error, dane wywołującego w $Task.State.

    .PARAMETER State
        Dowolne dane dla OnCompleted (np. identyfikator instancji).

    .PARAMETER Cancellable
        Czy zadanie można anulować z paska stanu.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Uruchamia zadanie; podgląd i potwierdzenie zmian należą do funkcji, którą zadanie wywołuje.')]
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [Collections.Generic.List[object]] $Registry,

        [Parameter(Mandatory)]
        [Management.Automation.Runspaces.RunspacePool] $Pool,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(Mandatory)]
        [scriptblock] $ScriptBlock,

        [AllowEmptyCollection()]
        [object[]] $ArgumentList = @(),

        [scriptblock] $OnCompleted,

        [AllowNull()]
        [object] $State,

        [switch] $Cancellable
    )

    $progress = [hashtable]::Synchronized(@{ Percent = -1; Message = ''; CancelRequested = $false })
    $worker = {
        param($Progress, [string] $ScriptText, [object[]] $Arguments)
        $code = [scriptblock]::Create($ScriptText)
        & $code $Progress @Arguments
    }

    $powerShell = [powershell]::Create()
    $powerShell.RunspacePool = $Pool
    $null = $powerShell.AddScript($worker.ToString()).AddArgument($progress).AddArgument($ScriptBlock.ToString()).AddArgument($ArgumentList)
    $task = [pscustomobject]@{
        PSTypeName  = 'MWP.UiTask'
        Id          = [guid]::NewGuid().ToString()
        Name        = $Name
        Kind        = 'Script'
        Status      = 'Running'
        StartedAt   = Get-Date
        CompletedAt = $null
        Progress    = $progress
        Output      = @()
        Error       = $null
        Warnings    = @()
        Cancellable = [bool]$Cancellable
        OnCompleted = $OnCompleted
        State       = $State
        PowerShell  = $powerShell
        AsyncResult = $null
        Operation   = $null
    }
    $task.AsyncResult = $powerShell.BeginInvoke()
    $Registry.Add($task)
    $task
}
