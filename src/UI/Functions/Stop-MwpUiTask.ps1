function Stop-MwpUiTask {
    <#
    .SYNOPSIS
        Anuluje zadanie GUI w tle (albo wszystkie anulowalne zadania z rejestru) bez blokowania okna.

    .DESCRIPTION
        Ustawia Progress.CancelRequested (zadanie może zakończyć się samo w bezpiecznym miejscu)
        i zatrzymuje wykonanie: zadanie skryptu przez BeginStop (asynchronicznie, wątek okna nie
        czeka), operację MWP.Remote przez Stop-MwpOperation. Wynik (status Cancelled) odbiera
        Update-MwpUiTask. Anulowanie nie cofa zmian, które zadanie zdążyło wykonać.

    .PARAMETER Task
        Zadanie do anulowania.

    .PARAMETER Registry
        Lista zadań okna: anuluje wszystkie zadania z Cancellable.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low', DefaultParameterSetName = 'Task')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Task')]
        [PSTypeName('MWP.UiTask')]
        [object] $Task,

        [Parameter(Mandatory, ParameterSetName = 'Registry')]
        [AllowEmptyCollection()]
        [Collections.Generic.List[object]] $Registry
    )

    $tasks = if ($PSCmdlet.ParameterSetName -eq 'Registry') { @($Registry.ToArray() | Where-Object { $_.Cancellable }) } else { @($Task) }
    foreach ($item in $tasks) {
        if ($item.Status -ne 'Running' -or -not $PSCmdlet.ShouldProcess($item.Name, 'Anulowanie zadania w tle')) {
            continue
        }
        $item.Progress.CancelRequested = $true
        if ($item.Kind -eq 'Operation') {
            $null = Stop-MwpOperation -Operation $item.Operation -Confirm:$false
        }
        elseif ($null -ne $item.PowerShell) {
            $null = $item.PowerShell.BeginStop($null, $null)
        }
    }
}
