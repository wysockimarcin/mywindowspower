function Test-MwpPresentationMode {
    <#
    .SYNOPSIS
        Sprawdza, czy host może pokazać instancję modułu w danym trybie prezentacji.

    .DESCRIPTION
        Tryby hosta w FAZIE 4: Embedded (widok w oknie głównym) i SeparateWindow (osobne okno).
        Moduł deklaruje tryby w SupportedPresentationModes kontraktu. Pusta lista oznacza moduł
        obszaru bez własnych widoków (do jego fazy): host pokazuje wtedy widok-zaślepkę w obu
        trybach (D-039). Tryby DashboardWidget (FAZA 5), Standalone i CLI (FAZA 19) nie są
        obsługiwane przez okno hosta.

    .PARAMETER Definition
        Definicja modułu (Get-MwpModuleDefinition).

    .PARAMETER Mode
        Embedded albo SeparateWindow.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [object] $Definition,

        [Parameter(Mandatory)]
        [ValidateSet('Embedded', 'SeparateWindow')]
        [string] $Mode
    )

    $modes = @($Definition.SupportedPresentationModes | Where-Object { -not [string]::IsNullOrEmpty($_) })
    if ($modes.Count -eq 0) {
        return $true
    }
    $modes -contains $Mode
}
