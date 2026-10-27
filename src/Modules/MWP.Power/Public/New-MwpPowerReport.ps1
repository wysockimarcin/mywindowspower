function New-MwpPowerReport {
    <#
    .SYNOPSIS
        Tworzy raport baterii (powercfg /batteryreport) albo raport energii (powercfg /energy) na komputerze docelowym i zwraca jego treść.

    .DESCRIPTION
        Raport powstaje na komputerze docelowym kontekstu (localhost albo zdalnym, D-019) w jego
        katalogu tymczasowym; treść HTML wraca przez to samo połączenie (Base64 w JSON), a katalog
        tymczasowy jest usuwany — na komputerze zdalnym nic nie zostaje. Zapis lokalny i otwarcie:
        Save-MwpPowerReport i Open-MwpPowerReport (D-044). Nie zmienia ustawień systemu.
        Raport energii trwa -DurationSeconds (domyślnie 60 s) i wymaga uprawnień administratora;
        raport baterii wymaga baterii. Błąd powercfg zwracamy z jego tekstem i podpowiedzią.
        Bez -AsOperation zwraca MWP.Result z obiektem MWP.PowerReport w Data (ReportKind,
        ComputerName, CreatedAt, ExitCode, Output, Content w Base64). Z -AsOperation — uchwyt
        MWP.Operation (Start-MwpOperation; limit czasu = czas pomiaru + 120 s); wynik zamienia
        Save-MwpPowerReport.

    .PARAMETER Kind
        Battery albo Energy.

    .PARAMETER DurationSeconds
        Czas pomiaru raportu energii (5–600 s).

    .EXAMPLE
        New-MwpPowerReport -Kind Battery | Save-MwpPowerReport
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Raport nie zmienia ustawień systemu; plik tymczasowy na komputerze docelowym jest usuwany.')]
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateSet('Battery', 'Energy')]
        [string] $Kind,

        [PSTypeName('MWP.ExecutionContext')]
        [object] $Context = (New-MwpExecutionContext),

        [ValidateRange(5, 600)]
        [int] $DurationSeconds = 60,

        [switch] $AsOperation
    )

    $operation = 'Power.Report.' + $Kind
    $block = Get-MwpPowerScript -Name Report
    $timeout = $DurationSeconds + 120
    if ($AsOperation) {
        return Start-MwpOperation -Context $Context -ScriptBlock $block -ArgumentList @($Kind, $DurationSeconds) -Operation $operation -TimeoutSeconds $timeout
    }
    $result = Invoke-MwpOnTarget -Context $Context -ScriptBlock $block -ArgumentList @($Kind, $DurationSeconds) -Operation $operation -TimeoutSeconds $timeout
    if (-not $result.Success) {
        return $result
    }
    Resolve-MwpPowerReport -Data $result -ComputerName $Context.ComputerName -Kind $Kind
}
