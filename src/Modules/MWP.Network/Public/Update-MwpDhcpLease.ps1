function Update-MwpDhcpLease {
    <#
    .SYNOPSIS
        Odnawia dzierżawę DHCP adaptera na komputerze docelowym (Win32_NetworkAdapterConfiguration.RenewDHCPLease, jak ipconfig /renew).

    .DESCRIPTION
        Operacja klasy Zmiana bez wpisu cofnięcia (D-049): dzierżawy nie da się przywrócić. Tylko
        odnowienie (bez zwalniania adresu). Wymaga administratora na komputerze docelowym (sprawdzane
        przed podglądem); adapter musi używać DHCP. Gdy serwer DHCP przydzieli inny adres, a adapterem
        idzie połączenie aplikacji z komputerem zdalnym, połączenie może zostać przerwane — podgląd
        o tym ostrzega. Wynik pokazuje adresy IPv4 przed i po.

    .EXAMPLE
        Update-MwpDhcpLease -InterfaceIndex 11 -WhatIf
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

    $operation = 'Network.RenewDhcp'
    $computerName = $Context.ComputerName
    $check = Get-MwpNetworkAdapterTarget -Context $Context -InterfaceIndex $InterfaceIndex -InterfaceGuid ([string]$InterfaceGuid) -Operation $operation -RequireAdministrator
    if (-not $check.Success) {
        return $check.Result
    }
    $adapter = $check.Adapter
    $common = @{ Operation = $operation; Target = ("adapter '{0}'" -f $adapter.Name); ComputerName = $computerName }
    if (-not $adapter.DhcpEnabled) {
        return New-MwpResult @common -Success $false -Message ("Adapter '{0}' na komputerze '{1}' ma adres statyczny (bez DHCP) — nie ma dzierżawy do odnowienia." -f $adapter.Name, $computerName)
    }
    if ($adapter.Status -ne 'Up') {
        return New-MwpResult @common -Success $false -Message ("Adapter '{0}' na komputerze '{1}' nie jest połączony ({2}) — odnowienie dzierżawy niemożliwe." -f $adapter.Name, $computerName, $adapter.StatusText)
    }
    $beforeText = if ($adapter.IPv4Text) { $adapter.IPv4Text } else { '(brak adresu IPv4)' }
    $action = 'Odnowienie dzierżawy DHCP (adres: {0}; bez wpisu cofnięcia){1}' -f $beforeText,
    $(if ($adapter.IsConnectionAdapter) { '. Uwaga: tym adapterem idzie połączenie z tym komputerem — zmiana adresu przez serwer DHCP przerwie połączenie.' } else { '' })
    $target = Format-MwpOperationTarget -Target $check.Target -ComputerName $computerName
    if (-not $PSCmdlet.ShouldProcess($target, $action)) {
        return New-MwpResult @common -Success $true -IsPreview -Before $beforeText -Message ('Podgląd: {0}.' -f $action)
    }
    $request = ConvertTo-Json -Compress -InputObject ([pscustomobject]@{ InterfaceIndex = $InterfaceIndex })
    $result = Invoke-MwpOnTarget -Context $Context -Operation $operation -ScriptBlock (Get-MwpNetworkScript -Name RenewDhcp) -ArgumentList @($request) -TimeoutSeconds 90
    $raw = if ($result.Success) { ConvertFrom-MwpNetworkJson -Data $result -Kind 'MWP.NetworkRenewRaw' } else { $null }
    $failure = if ($null -eq $raw) { $result.Message } elseif ($raw.Error) { [string]$raw.Error } elseif ([long]$raw.ReturnValue -notin 0, 1) { 'kod wyniku {0}' -f $raw.ReturnValue } else { $null }
    if ($failure) {
        $message = "Nie udało się odnowić dzierżawy DHCP adaptera '{0}' na komputerze '{1}': {2}" -f $adapter.Name, $computerName, $failure
        Write-MwpLog -Level Error -Source 'MWP.Network' -Operation $operation -ComputerName $computerName -Message $message
        return New-MwpResult @common -Success $false -Before $beforeText -Message $message -ErrorMessage $failure
    }
    $after = @($raw.After | Where-Object { $_ } | ForEach-Object { [string]$_ })
    $afterText = if ($after.Count -gt 0) { $after -join ', ' } else { '(brak adresu IPv4)' }
    $message = "Odnowiono dzierżawę DHCP adaptera '{0}' na komputerze '{1}' (adres: {2})." -f $adapter.Name, $computerName, $afterText
    Write-MwpLog -Level Info -Source 'MWP.Network' -Operation $operation -ComputerName $computerName -Message $message -Data @{ Before = $beforeText; After = $afterText }
    New-MwpResult @common -Success $true -Changed $true -Before $beforeText -After $afterText -Message $message
}
