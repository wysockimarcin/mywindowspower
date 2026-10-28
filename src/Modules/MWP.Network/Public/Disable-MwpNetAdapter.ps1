function Disable-MwpNetAdapter {
    <#
    .SYNOPSIS
        Wyłącza adapter sieciowy na komputerze docelowym, z automatycznym ponownym włączeniem bez zatwierdzenia.

    .DESCRIPTION
        Operacja zmieniająca (odwracalna, ale może odciąć łączność): ConfirmImpact High (D-027, D-049) —
        bez -Confirm:$false funkcja zawsze pyta. Wymaga administratora na komputerze docelowym
        (sprawdzane przed podglądem). Adapter, którym idzie połączenie aplikacji z komputerem zdalnym,
        wymaga jawnego -AllowConnectionAdapter (dodatkowe potwierdzenie) — po wyłączeniu połączenie
        zostanie przerwane i wróci dopiero po automatycznym włączeniu adaptera. Gdy -RollbackSeconds > 0
        (domyślnie 120 s), komputer docelowy sam włączy adapter, jeśli zmiana nie zostanie zatwierdzona
        (Approve-MwpNetworkChange). Wpis cofnięcia: Enable-MwpNetAdapter.

    .PARAMETER AllowConnectionAdapter
        Zgoda na wyłączenie adaptera używanego przez połączenie z tym komputerem.

    .PARAMETER RollbackSeconds
        Czas na zatwierdzenie (30–3600 s); 0 = bez automatycznego włączenia.

    .EXAMPLE
        Disable-MwpNetAdapter -InterfaceIndex 2 -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateRange(1, 2147483647)]
        [int] $InterfaceIndex,

        [ValidatePattern('^\{?[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}\}?$')]
        [string] $InterfaceGuid,

        [ValidateScript({ $_ -eq 0 -or ($_ -ge 30 -and $_ -le 3600) })]
        [int] $RollbackSeconds = 120,

        [switch] $AllowConnectionAdapter,

        [PSTypeName('MWP.ExecutionContext')]
        [object] $Context = (New-MwpExecutionContext)
    )

    $operation = 'Network.DisableAdapter'
    $computerName = $Context.ComputerName
    $check = Get-MwpNetworkAdapterTarget -Context $Context -InterfaceIndex $InterfaceIndex -InterfaceGuid ([string]$InterfaceGuid) -Operation $operation -RequireAdministrator -RejectPending
    if (-not $check.Success) {
        return $check.Result
    }
    $adapter = $check.Adapter
    $common = @{ Operation = $operation; Target = ("adapter '{0}'" -f $adapter.Name); ComputerName = $computerName }
    if (-not $adapter.IsEnabled) {
        return New-MwpResult @common -Success $true -Before $adapter.StatusText -After $adapter.StatusText -Message ("Adapter '{0}' na komputerze '{1}' już jest wyłączony." -f $adapter.Name, $computerName)
    }
    if ($adapter.IsConnectionAdapter -and -not $AllowConnectionAdapter) {
        return New-MwpResult @common -Success $false -Before $adapter.StatusText `
            -Message ("Adapterem '{0}' idzie połączenie aplikacji z komputerem '{1}' — wyłączenie przerwie połączenie. Wymagane dodatkowe potwierdzenie (-AllowConnectionAdapter)." -f $adapter.Name, $computerName)
    }
    $notes = @()
    if ($adapter.IsConnectionAdapter) {
        $notes += 'Połączenie z tym komputerem zostanie przerwane.'
    }
    elseif ($adapter.Status -eq 'Up') {
        $notes += 'Komputer straci łączność przez ten adapter.'
    }
    if ($RollbackSeconds -gt 0) {
        $notes += ('Bez zatwierdzenia w ciągu {0} s komputer sam włączy adapter ponownie.' -f $RollbackSeconds)
    }
    elseif ($adapter.IsConnectionAdapter) {
        $notes += 'Bez automatycznego włączenia — przywrócenie wymaga dostępu do komputera innym sposobem.'
    }
    $action = 'Wyłączenie adaptera ({0}). {1}' -f $adapter.StatusText, ($notes -join ' ')
    $target = Format-MwpOperationTarget -Target $check.Target -ComputerName $computerName
    if (-not $PSCmdlet.ShouldProcess($target, $action)) {
        return New-MwpResult @common -Success $true -IsPreview -Before $adapter.StatusText -After 'Wyłączony' -Message ('Podgląd: {0}' -f $action)
    }
    Invoke-MwpNetworkChange -Context $Context -Operation $operation -Kind AdapterDisable -Adapter $adapter -RollbackSeconds $RollbackSeconds `
        -Summary ("Wyłączenie adaptera '{0}'" -f $adapter.Name)
}
