function Register-MwpUiOperation {
    <#
    .SYNOPSIS
        Rejestruje operację asynchroniczną MWP.Remote (Start-MwpOperation) jako zadanie GUI.

    .DESCRIPTION
        Operacja na komputerze docelowym instancji działa w puli MWP.Remote (limit
        remoteMaxParallelOperations, limit czasu, anulowanie przez Stop-MwpOperation). Rejestracja
        pozwala oknu pokazać ją na pasku stanu, anulować i odebrać wynik w Update-MwpUiTask
        (wynik MWP.Result w $Task.Output, wywołanie OnCompleted w wątku okna).

    .PARAMETER Operation
        Uchwyt MWP.Operation z Start-MwpOperation.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [Collections.Generic.List[object]] $Registry,

        [Parameter(Mandatory)]
        [PSTypeName('MWP.Operation')]
        [object] $Operation,

        [ValidateNotNullOrEmpty()]
        [string] $Name = $Operation.Operation,

        [scriptblock] $OnCompleted,

        [AllowNull()]
        [object] $State
    )

    $task = [pscustomobject]@{
        PSTypeName  = 'MWP.UiTask'
        Id          = [guid]::NewGuid().ToString()
        Name        = $Name
        Kind        = 'Operation'
        Status      = 'Running'
        StartedAt   = Get-Date
        CompletedAt = $null
        Progress    = [hashtable]::Synchronized(@{ Percent = -1; Message = ("Komputer: {0}" -f $Operation.ComputerName); CancelRequested = $false })
        Output      = @()
        Error       = $null
        Warnings    = @()
        Cancellable = $true
        OnCompleted = $OnCompleted
        State       = $State
        PowerShell  = $null
        AsyncResult = $null
        Operation   = $Operation
    }
    $Registry.Add($task)
    $task
}
