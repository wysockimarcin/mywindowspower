function New-MwpUiTaskPool {
    <#
    .SYNOPSIS
        Tworzy pulę runspace'ów dla zadań w tle GUI, z zaimportowanymi modułami aplikacji.

    .DESCRIPTION
        Pomocnik zadań w tle (D-023, D-039). Zadania GUI (instalacja modułu, przeniesienie danych,
        łączenie z komputerem, test połączenia) wywołują funkcje MWP.Core i MWP.Remote, więc każdy
        runspace puli importuje ich manifesty. Odróżnia się to od puli Start-MwpOperation
        (MWP.Remote), która wykonuje samowystarczalne bloki na komputerze docelowym bez modułów MWP.
        Rejestry procesu (instancje) należą do runspace'u okna; zadanie w tle nie zamyka instancji.

    .PARAMETER ModulePath
        Ścieżki manifestów modułów do zaimportowania w każdym runspace.

    .PARAMETER MaximumRunspaces
        Limit równoczesnych zadań GUI (nadmiar czeka w kolejce).
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Tworzy tylko obiekt w pamięci procesu; nie zmienia stanu systemu.')]
    [CmdletBinding()]
    [OutputType([Management.Automation.Runspaces.RunspacePool])]
    param(
        [AllowEmptyCollection()]
        [string[]] $ModulePath = @(),

        [ValidateRange(1, 16)]
        [int] $MaximumRunspaces = 3
    )

    $sessionState = [Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
    if ($ModulePath.Count -gt 0) {
        $sessionState.ImportPSModule($ModulePath)
    }
    $pool = [runspacefactory]::CreateRunspacePool(1, $MaximumRunspaces, $sessionState, $Host)
    $pool.Open()
    $pool
}
