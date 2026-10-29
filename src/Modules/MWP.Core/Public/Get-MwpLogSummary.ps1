function Get-MwpLogSummary {
    <#
    .SYNOPSIS
        Podsumowanie dzisiejszego dziennika operacji aplikacji: liczba wpisów wg poziomu, ostatnie ostrzeżenia i błędy, liczba zmian do cofnięcia.

    .DESCRIPTION
        Funkcja danych widgetu „Dziennik operacji” (D-053). Tylko odczyt plików aplikacji na tym
        komputerze (dziennik i rejestr cofnięć leżą w katalogu danych komputera, na którym działa
        aplikacja), więc działa wyłącznie dla localhost (widget ma LocalOnly). Z -AsOperation zwraca
        uchwyt Start-MwpOperation (moduł MWP.Remote; MWP.Core nie może od niego zależeć, więc polecenie
        jest wyszukiwane w chwili wywołania, jak w Uninstall-MwpModulePackage); bez niego — MWP.Result
        z danymi Resolve-MwpLogSummary.

    .PARAMETER Context
        Kontekst wykonania (MWP.ExecutionContext); musi wskazywać komputer lokalny.

    .PARAMETER Level
        Poziomy wpisów na liście ostatnich (domyślnie Error).

    .PARAMETER Top
        Liczba ostatnich wpisów (1–50, domyślnie 5).

    .PARAMETER WidgetParameters
        Parametry widgetu: Levels (lista poziomów), Top (liczba).

    .EXAMPLE
        Get-MwpLogSummary -Level Warning, Error -Top 10
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Position = 0)]
        [AllowNull()]
        [object] $Context,

        [ValidateSet('Info', 'Warning', 'Error')]
        [string[]] $Level = @('Error'),

        [ValidateRange(1, 50)]
        [int] $Top = 5,

        [AllowNull()]
        [Collections.IDictionary] $WidgetParameters,

        [switch] $AsOperation
    )

    $operation = 'Core.LogSummary'
    $computerName = $(if ($null -ne $Context -and $null -ne $Context.PSObject.Properties['ComputerName']) { [string]$Context.ComputerName } else { 'localhost' })
    $common = @{ Operation = $operation; Target = 'dziennik operacji'; ComputerName = $computerName }
    if ($null -ne $WidgetParameters) {
        if (-not $PSBoundParameters.ContainsKey('Level') -and $WidgetParameters.Contains('Levels')) {
            $chosen = @(@($WidgetParameters['Levels']) | Where-Object { @('Info', 'Warning', 'Error') -contains $_ })
            if ($chosen.Count -gt 0) {
                $Level = [string[]]$chosen
            }
        }
        $number = 0
        if (-not $PSBoundParameters.ContainsKey('Top') -and $WidgetParameters.Contains('Top') -and [int]::TryParse([string]$WidgetParameters['Top'], [ref]$number)) {
            $Top = [Math]::Min(50, [Math]::Max(1, $number))
        }
    }
    if ($null -ne $Context -and $null -ne $Context.PSObject.Properties['Mode'] -and $Context.Mode -ne 'Local') {
        $message = "Dziennik operacji jest dostępny tylko dla komputera lokalnego (nie dla '{0}')." -f $computerName
        if ($AsOperation) {
            throw $message
        }
        return New-MwpResult @common -Success $false -Message $message
    }
    # Te same katalogi co Write-MwpLog i Save-MwpUndoEntry.
    $request = ConvertTo-Json -Compress -InputObject ([pscustomobject]@{
            LogPath  = [IO.Path]::Combine((Get-MwpDataPath -Kind Logs), ('mwp-{0:yyyy-MM-dd}.log' -f (Get-Date)))
            UndoPath = Get-MwpDataPath -Kind Undo
            Levels   = @($Level)
            Top      = $Top
        })
    $block = Get-MwpLogSummaryScript
    if ($AsOperation) {
        if ($null -eq $Context) {
            throw 'Operacja w tle wymaga kontekstu wykonania (-Context).'
        }
        $start = Get-Command -Name 'Start-MwpOperation' -ErrorAction SilentlyContinue
        if ($null -eq $start) {
            throw 'Brak modułu MWP.Remote (Start-MwpOperation): operacje w tle są niedostępne.'
        }
        return & $start -Context $Context -ScriptBlock $block -ArgumentList @($request) -Operation $operation
    }
    try {
        $raw = & $block $request
    }
    catch {
        return New-MwpResult @common -Success $false -Message ('Nie udało się odczytać dziennika operacji: {0}' -f $_.Exception.Message) -ErrorMessage $_.Exception.Message
    }
    $summary = Resolve-MwpLogSummary -Data $raw
    New-MwpResult @common -Success $true -Message ('Dziennik operacji: błędy {0}, ostrzeżenia {1}.' -f $summary.Counts.Error, $summary.Counts.Warning) -Data $summary
}
