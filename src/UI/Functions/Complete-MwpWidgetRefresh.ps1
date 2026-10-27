function Complete-MwpWidgetRefresh {
    <#
    .SYNOPSIS
        Obsługuje wynik odświeżenia widgetu (wątek okna): stan, widok z funkcji widoku modułu, termin następnego odświeżenia.

    .DESCRIPTION
        Wywoływana z OnCompleted zadania (Update-MwpUiTask). Stan ustala Get-MwpWidgetStatus. Przy
        stanie Ready funkcja widoku (ViewCommand, D-043) zamienia dane na MWP.WidgetView; jej wyjątek
        albo pusty widok daje Error albo NoData. Przy błędzie i utracie połączenia widget zachowuje
        ostatni widok (z komunikatem), żeby użytkownik widział ostatnie znane dane. Widget usunięty
        w trakcie odświeżania jest pomijany. Następne odświeżenie automatyczne: teraz + refreshSeconds
        (0 = tylko ręcznie).

    .PARAMETER Widget
        Widget (tabela z New-MwpWidgetRuntime).

    .PARAMETER Task
        Zadanie GUI (MWP.UiTask) z wynikiem w Output.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Zmienia tylko stan widgetu w pamięci okna.')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable] $Widget,

        [Parameter(Mandatory)]
        [object] $Task,

        [datetime] $Now = (Get-Date)
    )

    $Widget.Task = $null
    if ($Widget.Removed) {
        return
    }
    $result = @($Task.Output | Where-Object { $null -ne $_ -and $_.PSObject.TypeNames -contains 'MWP.Result' }) | Select-Object -Last 1
    $status = Get-MwpWidgetStatus -Result $result -TaskStatus ([string]$Task.Status) -TaskError ([string]$Task.Error)
    $Widget.Version++
    $Widget.LastAttempt = $Now
    $refresh = [int]$Widget.Config['refreshSeconds']
    $Widget.NextRefresh = $(if ($refresh -gt 0) { $Now.AddSeconds($refresh) } else { [datetime]::MaxValue })

    if ($status.Status -eq 'Cancelled') {
        $Widget.Status = $(if ($null -ne $Widget.View) { 'Ready' } else { 'Idle' })
        $Widget.Message = $status.Message
        return
    }
    if ($status.Status -eq 'Ready') {
        try {
            $command = $Widget.Definition.ViewCommand
            $view = & $command -Data $result.Data -WidgetParameters $Widget.Parameters
            if ($null -eq $view) {
                $Widget.Status = 'NoData'
                $Widget.Message = 'Komputer nie zwrócił danych dla tego widgetu.'
                $Widget.View = $null
            }
            else {
                $Widget.Status = 'Ready'
                $Widget.Message = $null
                $Widget.View = $view
                $Widget.Data = $result.Data
            }
        }
        catch {
            $Widget.Status = 'Error'
            $Widget.Message = 'Nie udało się przygotować widoku widgetu: {0}' -f $_.Exception.Message
        }
        $Widget.LastRefresh = $Now
        return
    }
    $Widget.Status = $status.Status
    $Widget.Message = $status.Message
    if ($status.Status -eq 'NoData') {
        $Widget.View = $null
        $Widget.LastRefresh = $Now
    }
}
