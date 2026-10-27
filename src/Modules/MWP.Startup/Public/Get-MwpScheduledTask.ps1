function Get-MwpScheduledTask {
    <#
    .SYNOPSIS
        Odczytuje zadania harmonogramu na komputerze docelowym: stan, akcje, wyzwalacze, konto, ostatnie i następne uruchomienie, podpis wydawcy, lista ochronna.

    .DESCRIPTION
        Operacja klasy Odczyt (nic nie zmienia). Jedno wywołanie na komputerze kontekstu (localhost
        albo zdalnym, D-019): Get-ScheduledTask i Get-ScheduledTaskInfo. Podpis pliku pierwszej
        akcji jest sprawdzany dla zadań spoza folderu \Microsoft\ (zadania systemowe: „nie
        sprawdzano”, żeby odczyt ok. 200 zadań trwał 2–3 s, a nie kilkadziesiąt). Bez uprawnień
        administratora system pokazuje tylko część zadań. Filtry jak w Select-MwpScheduledTask.
        Bez -AsOperation zwraca MWP.Result z MWP.ScheduledTaskList w Data (zadania w polu Tasks).
        Z -AsOperation zwraca uchwyt MWP.Operation; surowy JSON zamienia Resolve-MwpScheduledTaskList.

    .EXAMPLE
        (Get-MwpScheduledTask -HideMicrosoft).Data.Tasks | Format-Table Path, StateText, RiskText, Publisher

    .EXAMPLE
        (Get-MwpScheduledTask -Context $remote -State Disabled).Data.Tasks
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Position = 0)]
        [PSTypeName('MWP.ExecutionContext')]
        [object] $Context = (New-MwpExecutionContext),

        [ValidateSet('All', 'Enabled', 'Disabled', 'Running')]
        [string] $State = 'All',

        [switch] $HideMicrosoft,

        [switch] $ProtectedOnly,

        [AllowEmptyString()]
        [string] $Search = '',

        [switch] $NoSignature,

        [switch] $AsOperation
    )

    $operation = 'Startup.ListTasks'
    if ($AsOperation) {
        return Invoke-MwpStartupRead -Context $Context -Operation $operation -Kind Task -NoSignature:$NoSignature -AsOperation
    }
    $common = @{ Operation = $operation; Target = $Context.ComputerName; ComputerName = $Context.ComputerName }
    $read = Invoke-MwpStartupRead -Context $Context -Operation $operation -Kind Task -NoSignature:$NoSignature
    if (-not $read.Success) {
        return New-MwpResult @common -Success $false -Message $read.Result.Message -ErrorMessage $read.Result.ErrorMessage
    }
    $list = Resolve-MwpScheduledTaskList -Data $read.Raw
    $all = @($list.Tasks).Count
    $list.Tasks = @(Select-MwpScheduledTask -Task $list.Tasks -State $State -HideMicrosoft:$HideMicrosoft -ProtectedOnly:$ProtectedOnly -Search $Search)
    $shown = @($list.Tasks).Count
    $message = if ($shown -eq $all) {
        "Odczytano {0} zadań harmonogramu komputera '{1}'." -f $all, $Context.ComputerName
    }
    else {
        "Odczytano {0} zadań harmonogramu komputera '{1}' (po filtrach: {2})." -f $all, $Context.ComputerName, $shown
    }
    New-MwpResult @common -Success $true -Message $message -Data $list
}
