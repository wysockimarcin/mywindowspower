function Get-MwpPowerPlan {
    <#
    .SYNOPSIS
        Zwraca listę planów zasilania komputera docelowego (GUID, nazwa, czy aktywny, czy wbudowany).

    .DESCRIPTION
        Operacja klasy Odczyt: powercfg /list na komputerze kontekstu, parsowanie po GUID-ach
        (nazwy planów są w języku systemu). Zwraca MWP.Result z listą MWP.PowerPlan w Data.

    .PARAMETER Guid
        Zwraca tylko plan o tym GUID (Data pusta, gdy go nie ma).

    .EXAMPLE
        (Get-MwpPowerPlan).Data | Where-Object IsActive
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Position = 0)]
        [PSTypeName('MWP.ExecutionContext')]
        [object] $Context = (New-MwpExecutionContext),

        [ValidatePattern('^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$')]
        [string] $Guid
    )

    $operation = 'Power.ListPlans'
    $common = @{ Operation = $operation; Target = $Context.ComputerName; ComputerName = $Context.ComputerName }
    $read = Invoke-MwpPowercfg -Context $Context -Command @(Get-MwpPowerQueryCommand -Setting @()) -Operation $operation
    if (-not $read.Success) {
        return $read.Result
    }
    $list = Get-MwpPowercfgCommand -Raw $read.Raw -Id 'list'
    if (-not $list.Success) {
        return New-MwpResult @common -Success $false -Message ("Nie udało się odczytać planów zasilania na komputerze '{0}': {1}" -f $Context.ComputerName, $list.Message)
    }
    $plans = @((Resolve-MwpPowerStatus -Data $read.Raw).Plans)
    if ($PSBoundParameters.ContainsKey('Guid')) {
        $plans = @($plans | Where-Object { $_.Guid -eq $Guid.ToLowerInvariant() })
    }
    New-MwpResult @common -Success $true -Message ("Plany zasilania komputera '{0}': {1}." -f $Context.ComputerName, $plans.Count) -Data $plans
}
