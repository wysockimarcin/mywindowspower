function Get-MwpPowerStatus {
    <#
    .SYNOPSIS
        Odczytuje stan zasilania komputera docelowego: plany, plan aktywny, czasy wygaszania i uśpienia (AC/DC), akcje przycisków i pokrywy, hibernację, szybkie uruchamianie.

    .DESCRIPTION
        Operacja klasy Odczyt (nic nie zmienia). Jedno wywołanie na komputerze kontekstu (localhost
        albo zdalnym, D-019): powercfg /list i /qh dla każdego ustawienia planu aktywnego oraz rejestr
        (HibernateEnabled, HiberbootEnabled), bateria (CIM) i uprawnienia. Parsowanie po GUID-ach,
        niezależnie od języka systemu (Resolve-MwpPowerStatus).
        Bez -AsOperation zwraca MWP.Result z obiektem MWP.PowerStatus w Data. Z -AsOperation startuje
        w puli runspace'ów (Start-MwpOperation) i zwraca uchwyt MWP.Operation; Data wyniku zawiera
        wtedy surowy tekst JSON, który zamienia Resolve-MwpPowerStatus (widok i widget robią to same).
        Tak korzysta z niej widget Dashboardu (kontrakt widgetu, D-043).

    .PARAMETER WidgetParameters
        Parametry widgetu (kontrakt D-043); widget zasilania nie ma parametrów.

    .EXAMPLE
        (Get-MwpPowerStatus -Context (New-MwpExecutionContext)).Data.Settings | Format-Table Label, AcText, DcText
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'WidgetParameters',
        Justification = 'Parametr wymagany przez kontrakt widgetu (D-043); widget zasilania nie ma parametrów.')]
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Position = 0)]
        [PSTypeName('MWP.ExecutionContext')]
        [object] $Context = (New-MwpExecutionContext),

        [AllowNull()]
        [Collections.IDictionary] $WidgetParameters,

        [switch] $AsOperation
    )

    $operation = 'Power.Status'
    $commands = @(Get-MwpPowerQueryCommand)
    if ($AsOperation) {
        return Invoke-MwpPowercfg -Context $Context -Command $commands -Operation $operation -IncludeSystem -AsOperation
    }
    $read = Invoke-MwpPowercfg -Context $Context -Command $commands -Operation $operation -IncludeSystem
    if (-not $read.Success) {
        return $read.Result
    }
    $status = Resolve-MwpPowerStatus -Data $read.Raw
    $list = Get-MwpPowercfgCommand -Raw $read.Raw -Id 'list'
    if (-not $list.Success) {
        return New-MwpResult -Success $false -Operation $operation -Target $Context.ComputerName -ComputerName $Context.ComputerName `
            -Message ("Nie udało się odczytać planów zasilania na komputerze '{0}': {1}" -f $Context.ComputerName, $list.Message) -Data $status
    }
    New-MwpResult -Success $true -Operation $operation -Target $Context.ComputerName -ComputerName $Context.ComputerName `
        -Message ("Odczytano stan zasilania komputera '{0}'." -f $Context.ComputerName) -Data $status
}
