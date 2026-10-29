function Close-MwpUiSession {
    <#
    .SYNOPSIS
        Sprząta po oknie głównym: zegar, zadania w tle, instancje modułów i ich osobne okna.

    .DESCRIPTION
        Każda instancja (także instancje widgetów Dashboardu) jest zamykana przez Close-MwpModuleInstance
        (anulowanie operacji, zamknięcie sesji, usunięcie poświadczeń z pamięci); błąd jednej nie
        przerywa zamykania pozostałych. Konfiguracja Dashboardu jest zapisywana na bieżąco, nie tu.
    #>
    [CmdletBinding()]
    param()

    $ui = $script:MwpUi
    if ($null -eq $ui) {
        return
    }
    $ui.Closing = $true
    if ($null -ne $ui.Timer) {
        $ui.Timer.Stop()
    }
    Close-MwpUiTaskPool -Registry $ui.Tasks -Pool $ui.Pool
    $ui.Pool = $null
    foreach ($entry in @($ui.Instances.Values)) {
        try {
            if ($null -ne $entry.Window) {
                $entry.Reattaching = $true
                $entry.Window.Close()
            }
            $null = Close-MwpModuleInstance -Instance $entry.Instance
        }
        catch {
            Write-Warning ("Zamykanie instancji '{0}': {1}" -f $entry.Instance.Name, $_.Exception.Message)
        }
    }
    $ui.Instances.Clear()
    if ($null -ne $ui.Dashboard) {
        foreach ($widget in @($ui.Dashboard.Widgets)) {
            Remove-MwpWidgetRuntime -Widget $widget -Confirm:$false
        }
        $ui.Dashboard.Widgets.Clear()
    }
    # D-052: hasła z pamięci procesu nie zostają w konsoli, z której uruchomiono okno (magazyn bez zmian).
    try {
        $null = Clear-MwpTargetCredentialCache
    }
    catch {
        Write-Verbose $_.Exception.Message
    }
    try {
        Write-MwpLog -Level Info -Source 'MWP.UI' -Operation 'UI.Close' -Message 'Zamknięto okno aplikacji.'
    }
    catch {
        Write-Verbose $_.Exception.Message
    }
}
