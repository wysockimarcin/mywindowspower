function Close-MwpUiSession {
    <#
    .SYNOPSIS
        Sprząta po oknie głównym: zegar, zadania w tle, instancje modułów i ich osobne okna.

    .DESCRIPTION
        Każda instancja jest zamykana przez Close-MwpModuleInstance (anulowanie operacji, zamknięcie
        sesji, usunięcie poświadczeń z pamięci); błąd jednej nie przerywa zamykania pozostałych.
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
    try {
        Write-MwpLog -Level Info -Source 'MWP.UI' -Operation 'UI.Close' -Message 'Zamknięto okno aplikacji.'
    }
    catch {
        Write-Verbose $_.Exception.Message
    }
}
