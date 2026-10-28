function Get-MwpNetworkDetail {
    <#
    .SYNOPSIS
        Zwraca tytuł i opis szczegółów adaptera sieciowego do widoku sieci.

    .DESCRIPTION
        Czysta funkcja (bez WPF): stan i prędkość, MAC, adresy IPv4 i IPv6, brama, DNS (tryb i skuteczne
        serwery), DHCP z dzierżawą, profil sieci, adapter połączenia zdalnego.

    .PARAMETER Adapter
        MWP.NetAdapter albo $null.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [AllowNull()]
        [object] $Adapter
    )

    if ($null -eq $Adapter) {
        return [pscustomobject]@{ Title = 'Wybierz adapter z listy.'; Text = '' }
    }
    $none = '—'
    $lines = @(
        'Stan: {0}{1}' -f $Adapter.StatusText, $(if ($Adapter.LinkSpeed -and $Adapter.Status -eq 'Up') { ', ' + $Adapter.LinkSpeed } else { '' })
        'MAC: {0} · indeks {1}{2}' -f $(if ($Adapter.MacAddress) { $Adapter.MacAddress } else { $none }), $Adapter.InterfaceIndex, $(if ($Adapter.Virtual) { ' · wirtualny' } else { '' })
        'IPv4: {0}' -f $(if ($Adapter.IPv4Text) { $Adapter.IPv4Text } else { $none })
        'IPv6: {0}' -f $(if (@($Adapter.IPv6).Count -gt 0) { @($Adapter.IPv6) -join ', ' } elseif ($Adapter.HasIPv6) { $none } else { 'wyłączony' })
        'Brama: {0}' -f $(if ($Adapter.GatewayText) { $Adapter.GatewayText } else { $none })
        'DNS: {0}{1}' -f $(if ($Adapter.DnsMode -eq 'Static') { 'ustawione ręcznie' } else { 'automatycznie (DHCP)' }), $(if ($Adapter.DnsServersText) { ' — w użyciu: ' + $Adapter.DnsServersText } else { '' })
        'DHCP: {0}' -f $(if (-not $Adapter.DhcpEnabled) { 'nie (adres statyczny)' } else {
                'tak{0}{1}' -f $(if ($Adapter.DhcpServer) { ', serwer ' + $Adapter.DhcpServer } else { '' }), $(if ($null -ne $Adapter.LeaseExpires) { ', dzierżawa do {0:yyyy-MM-dd HH:mm}' -f $Adapter.LeaseExpires } else { '' })
            })
        'Profil sieci: {0}' -f $(if ($Adapter.ProfileName) { '{0} ({1})' -f $Adapter.ProfileName, $Adapter.CategoryText } else { $none })
    )
    if ($Adapter.IsConnectionAdapter) {
        $lines += 'Tym adapterem idzie połączenie aplikacji z tym komputerem — wyłączenie albo zmiana adresu przerwie połączenie.'
    }
    [pscustomobject]@{
        Title = '{0} — {1}' -f $Adapter.Name, $Adapter.Description
        Text  = $lines -join [Environment]::NewLine
    }
}
