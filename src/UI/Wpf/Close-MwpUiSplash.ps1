function Close-MwpUiSplash {
    <#
    .SYNOPSIS
        Zamyka okno startowe launchera (D-042) po pierwszym wyświetleniu okna głównego albo przy błędzie.

    .DESCRIPTION
        Okno startowe przychodzi z launchera w StartupTiming['Splash'] (obiekt Show-MwpSplash ze
        src\UI\Splash.ps1). Wielokrotne wywołanie jest bezpieczne. Błąd zamknięcia nie przerywa okna
        głównego: trafia do logu jako ostrzeżenie (Startup.Splash).
    #>
    [CmdletBinding()]
    param()

    $startup = $script:MwpUi.Startup
    if ($null -eq $startup -or $null -eq $startup.Timing) {
        return
    }
    $splash = $startup.Timing['Splash']
    if ($null -eq $splash -or $splash.Closed) {
        return
    }
    $splash.Closed = $true
    try {
        $splash.Window.Close()
    }
    catch {
        Write-MwpLog -Level Warning -Source 'Launcher' -Operation 'Startup.Splash' -Message ("Nie udało się zamknąć okna startowego: {0}" -f $_.Exception.Message)
    }
}
