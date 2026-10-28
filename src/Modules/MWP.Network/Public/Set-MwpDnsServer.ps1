function Set-MwpDnsServer {
    <#
    .SYNOPSIS
        Zmienia serwery DNS adaptera na komputerze docelowym: preset (DHCP, Cloudflare, Google, Quad9) albo własne adresy; z cofaniem i automatycznym wycofaniem bez zatwierdzenia.

    .DESCRIPTION
        Operacja klasy Zmiana (D-027, D-049). Najpierw reset do DHCP (Set-DnsClientServerAddress
        -ResetServerAddresses), potem — gdy lista nie jest pusta — statyczna lista (adresy IPv6 tylko na
        adapterach z IPv6) i opróżnienie pamięci DNS. Wymaga administratora na komputerze docelowym
        (sprawdzane przed podglądem); podgląd (-WhatIf) i potwierdzenie z nazwą komputera; stan przed
        zmianą to statyczne serwery z rejestru (Tcpip/Tcpip6), więc cofnięcie przywraca dokładnie ten
        sam tryb (DHCP albo lista). Gdy -RollbackSeconds > 0 (domyślnie 120 s), przed zmianą na komputerze
        docelowym powstaje jednorazowe zadanie wycofania: bez Approve-MwpNetworkChange w tym czasie
        komputer sam przywraca poprzednie DNS — także po utracie połączenia. Zmiana adaptera, na którym
        czeka niezatwierdzona zmiana, jest odrzucana.

    .PARAMETER InterfaceIndex
        Indeks adaptera (Get-MwpNetworkStatus).

    .PARAMETER InterfaceGuid
        Opcjonalny identyfikator adaptera — zmiana zostanie odrzucona, gdy indeks wskazuje inny adapter.

    .PARAMETER Preset
        Dhcp, Cloudflare, Google albo Quad9 (Get-MwpDnsPreset).

    .PARAMETER ServerAddress
        Własne adresy serwerów DNS (IPv4 i IPv6, 1–8).

    .PARAMETER RollbackSeconds
        Czas na zatwierdzenie (30–3600 s); 0 = bez automatycznego wycofania.

    .EXAMPLE
        Set-MwpDnsServer -InterfaceIndex 11 -Preset Cloudflare -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium', DefaultParameterSetName = 'Preset')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateRange(1, 2147483647)]
        [int] $InterfaceIndex,

        [ValidatePattern('^\{?[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}\}?$')]
        [string] $InterfaceGuid,

        [Parameter(Mandatory, ParameterSetName = 'Preset')]
        [ValidateSet('Dhcp', 'Cloudflare', 'Google', 'Quad9')]
        [string] $Preset,

        [Parameter(Mandatory, ParameterSetName = 'Custom')]
        [ValidateCount(1, 8)]
        [string[]] $ServerAddress,

        [ValidateScript({ $_ -eq 0 -or ($_ -ge 30 -and $_ -le 3600) })]
        [int] $RollbackSeconds = 120,

        [PSTypeName('MWP.ExecutionContext')]
        [object] $Context = (New-MwpExecutionContext)
    )

    $operation = 'Network.SetDns'
    $computerName = $Context.ComputerName
    $common = @{ Operation = $operation; Target = ('adapter {0}' -f $InterfaceIndex); ComputerName = $computerName }
    if ($PSCmdlet.ParameterSetName -eq 'Preset') {
        $definition = Get-MwpDnsPreset -Name $Preset
        $servers = @($definition.Servers)
        $label = $definition.Label
    }
    else {
        $parsed = ConvertTo-MwpDnsServerAddress -Address $ServerAddress
        if ($parsed.Error) {
            return New-MwpResult @common -Success $false -Message $parsed.Error
        }
        $servers = @($parsed.Addresses)
        if ($servers.Count -eq 0) {
            return New-MwpResult @common -Success $false -Message 'Podaj co najmniej jeden adres serwera DNS.'
        }
        $label = 'własne adresy'
    }

    $check = Get-MwpNetworkAdapterTarget -Context $Context -InterfaceIndex $InterfaceIndex -InterfaceGuid ([string]$InterfaceGuid) -Operation $operation -RequireAdministrator -RejectPending
    if (-not $check.Success) {
        return $check.Result
    }
    $adapter = $check.Adapter
    $common.Target = "adapter '{0}'" -f $adapter.Name
    if (-not $adapter.HasIPv6) {
        $servers = @($servers | Where-Object { $_ -notmatch ':' })
        if ($servers.Count -eq 0 -and $PSCmdlet.ParameterSetName -eq 'Custom') {
            return New-MwpResult @common -Success $false -Message ("Adapter '{0}' nie ma włączonego IPv6 — podaj adresy IPv4." -f $adapter.Name)
        }
    }
    $beforeText = $adapter.DnsText
    $afterText = Format-MwpDnsServerText -Server $servers
    if ($beforeText -eq $afterText) {
        return New-MwpResult @common -Success $true -Before $beforeText -After $afterText -Message ("DNS adaptera '{0}' na komputerze '{1}' już jest ustawiony: {2}." -f $adapter.Name, $computerName, $afterText)
    }

    $notes = @()
    if ($adapter.IsConnectionAdapter) {
        $notes += 'Uwaga: tym adapterem idzie połączenie aplikacji z tym komputerem.'
    }
    if ($RollbackSeconds -gt 0) {
        $notes += ('Bez zatwierdzenia w ciągu {0} s komputer sam przywróci poprzednie DNS ({1}).' -f $RollbackSeconds, $beforeText)
    }
    $action = 'Zmiana DNS ({0}): {1} → {2}{3}' -f $label, $beforeText, $afterText, $(if ($notes.Count -gt 0) { '. ' + ($notes -join ' ') } else { '' })
    $target = Format-MwpOperationTarget -Target $check.Target -ComputerName $computerName
    if (-not $PSCmdlet.ShouldProcess($target, $action)) {
        return New-MwpResult @common -Success $true -IsPreview -Before $beforeText -After $afterText -Message ('Podgląd: {0}.' -f $action)
    }
    Invoke-MwpNetworkChange -Context $Context -Operation $operation -Kind Dns -Adapter $adapter -ServerAddress $servers -RollbackSeconds $RollbackSeconds `
        -Summary ("Zmiana DNS adaptera '{0}' ({1})" -f $adapter.Name, $label)
}
