function Invoke-MwpUiTick {
    <#
    .SYNOPSIS
        Krok zegara okna (wątek UI): wyniki zadań w tle, pasek stanu, stan połączeń, panel logu.

    .DESCRIPTION
        Co 250 ms: Update-MwpUiTask (OnCompleted zadań w wątku okna), postęp na pasku stanu
        i harmonogram widgetów Dashboardu (Invoke-MwpUiDashboardTick, FAZA 5).
        Co sekundę: plakietki stanu połączenia widoków instancji (stan zmieniają zadania w tle)
        i pasek stanu instancji. Co 5 sekund: panel logu, gdy jest widoczny. Błąd nie zatrzymuje
        zegara (komunikat tylko w konsoli, żeby nie zasypać użytkownika oknami).
    #>
    [CmdletBinding()]
    param()

    $ui = $script:MwpUi
    if ($null -eq $ui -or $ui.Closing) {
        return
    }
    try {
        $ui.Ticks++
        $summary = Update-MwpUiTask -Registry $ui.Tasks
        $c = $ui.Controls
        $c['StatusTaskText'].Text = $summary.Message
        if ($summary.Running -gt 0) {
            $c['StatusProgress'].Visibility = 'Visible'
            $c['StatusProgress'].IsIndeterminate = $summary.Percent -lt 0
            if ($summary.Percent -ge 0) {
                $c['StatusProgress'].Value = $summary.Percent
            }
        }
        else {
            $c['StatusProgress'].Visibility = 'Collapsed'
        }
        $c['StatusCancelButton'].Visibility = $(if ($summary.CanCancel) { 'Visible' } else { 'Collapsed' })
        if ($null -ne $ui.DemoTask) {
            Update-MwpAboutDemo
        }
        Invoke-MwpUiDashboardTick
        if ($summary.Completed.Count -gt 0 -or ($ui.Ticks % 4) -eq 0) {
            foreach ($entry in @($ui.Instances.Values)) {
                Update-MwpInstanceView -Entry $entry -StateOnly
            }
            Update-MwpStatusInstance
        }
        $key = [string]$ui.CurrentKey
        if (($key -eq 'dashboard' -or $key.StartsWith('area:')) -and ($summary.Completed.Count -gt 0 -or ($ui.Ticks % 8) -eq 0)) {
            Update-MwpCurrentView
        }
        if ($ui.LogVisible -and (($ui.Ticks % 20) -eq 0 -or $summary.Completed.Count -gt 0)) {
            Update-MwpLogPanel
        }
    }
    catch {
        Write-Warning ("Zegar okna: {0}" -f $_.Exception.Message)
    }
}
