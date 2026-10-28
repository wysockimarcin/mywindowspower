function Enable-MwpNetAdapter {
    <#
    .SYNOPSIS
        Włącza adapter sieciowy na komputerze docelowym.

    .DESCRIPTION
        Operacja klasy Zmiana (D-027, D-049): administrator na komputerze docelowym (sprawdzane przed
        podglądem), podgląd (-WhatIf) i potwierdzenie z nazwą komputera, log i wpis cofnięcia
        (Disable-MwpNetAdapter bez automatycznego włączenia). Bez zadania wycofania — włączenie nie
        odcina łączności. Polecenie cofające wyłączenie adaptera.

    .EXAMPLE
        Enable-MwpNetAdapter -InterfaceIndex 2 -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateRange(1, 2147483647)]
        [int] $InterfaceIndex,

        [ValidatePattern('^\{?[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}\}?$')]
        [string] $InterfaceGuid,

        [PSTypeName('MWP.ExecutionContext')]
        [object] $Context = (New-MwpExecutionContext)
    )

    $operation = 'Network.EnableAdapter'
    $computerName = $Context.ComputerName
    $check = Get-MwpNetworkAdapterTarget -Context $Context -InterfaceIndex $InterfaceIndex -InterfaceGuid ([string]$InterfaceGuid) -Operation $operation -RequireAdministrator
    if (-not $check.Success) {
        return $check.Result
    }
    $adapter = $check.Adapter
    $common = @{ Operation = $operation; Target = ("adapter '{0}'" -f $adapter.Name); ComputerName = $computerName }
    if ($adapter.IsEnabled) {
        return New-MwpResult @common -Success $true -Before $adapter.StatusText -After $adapter.StatusText -Message ("Adapter '{0}' na komputerze '{1}' już jest włączony." -f $adapter.Name, $computerName)
    }
    $action = 'Włączenie adaptera ({0})' -f $adapter.StatusText
    $target = Format-MwpOperationTarget -Target $check.Target -ComputerName $computerName
    if (-not $PSCmdlet.ShouldProcess($target, $action)) {
        return New-MwpResult @common -Success $true -IsPreview -Before $adapter.StatusText -After 'Włączony' -Message ('Podgląd: {0}.' -f $action)
    }
    Invoke-MwpNetworkChange -Context $Context -Operation $operation -Kind AdapterEnable -Adapter $adapter -Summary ("Włączenie adaptera '{0}'" -f $adapter.Name)
}
