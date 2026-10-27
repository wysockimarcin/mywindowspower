function Write-MwpUiStartupEntry {
    <#
    .SYNOPSIS
        Zapisuje wpis Startup.Window: czas od startu launchera do pierwszego wyświetlenia okna (D-042).

    .DESCRIPTION
        Wywoływana raz, w zdarzeniu ContentRendered okna głównego. Etapy (ms): środowisko, import
        MWP.Core, import pozostałych modułów, zapis dziennika startu, import MWP.UI, budowa okna (do
        ContentRendered); łącznie od startu launchera i od startu procesu PowerShella. Bez pomiaru
        z launchera (StartupTiming) nic nie zapisuje.
    #>
    [CmdletBinding()]
    param()

    $startup = $script:MwpUi.Startup
    if ($startup.Rendered) {
        return
    }
    $startup.Rendered = $true
    $timing = $startup.Timing
    if ($null -eq $timing -or $null -eq $timing['Stopwatch']) {
        return
    }

    $totalMs = $timing['Stopwatch'].ElapsedMilliseconds
    $stages = $timing['Stages']
    $data = [ordered]@{
        EventTime       = (Get-Date).ToString('o')
        EnvironmentMs   = $stages['EnvironmentMs']
        CoreImportMs    = $stages['CoreImportMs']
        ModulesImportMs = $stages['ModulesImportMs']
        StartupLogMs    = $stages['StartupLogMs']
        UiModuleMs      = $null
        WindowBuildMs   = $null
        TotalMs         = $totalMs
        ProcessTotalMs  = $null
    }
    if ($null -ne $startup.UiStartMs) {
        if ($null -ne $stages['BeforeWindowMs']) {
            $data.UiModuleMs = $startup.UiStartMs - $stages['BeforeWindowMs']
        }
        $data.WindowBuildMs = $totalMs - $startup.UiStartMs
    }
    if ($timing['ProcessStart'] -is [datetime]) {
        $data.ProcessTotalMs = [long]((Get-Date) - $timing['ProcessStart']).TotalMilliseconds
    }
    $message = "Okno aplikacji gotowe po {0} ms od startu launchera (od startu procesu: {1} ms)." -f $totalMs, $data.ProcessTotalMs
    Write-MwpLog -Level Info -Source 'Launcher' -Operation 'Startup.Window' -Message $message -Data $data
}
