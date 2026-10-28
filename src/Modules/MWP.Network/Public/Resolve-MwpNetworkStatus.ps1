function Resolve-MwpNetworkStatus {
    <#
    .SYNOPSIS
        Zamienia surowy wynik odczytu stanu sieci (Get-MwpNetworkStatus -AsOperation, blok Status) na obiekt MWP.NetworkStatus.

    .DESCRIPTION
        Czysta funkcja (bez wywołań na komputerze docelowym): przyjmuje tekst JSON, MWP.Result z operacji
        w tle albo obiekt surowy; gotowy MWP.NetworkStatus jest zwracany bez zmian. Adapter
        (MWP.NetAdapter) dostaje opisy po polsku: stan, profil sieci, DNS (statyczne serwery albo
        „automatycznie (DHCP)”) i znacznik adaptera połączenia zdalnego. Zmiany czekające na
        zatwierdzenie (MWP.NetworkPendingChange) mają termin wycofania i liczbę sekund pozostałych
        w chwili odczytu (zegar komputera docelowego). Zwraca $null, gdy danych nie ma.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Position = 0)]
        [AllowNull()]
        [object] $Data
    )

    if ($null -ne $Data -and $Data.PSObject.TypeNames -contains 'MWP.NetworkStatus') {
        return $Data
    }
    $raw = ConvertFrom-MwpNetworkJson -Data $Data -Kind 'MWP.NetworkStatusRaw'
    if ($null -eq $raw) {
        return $null
    }
    $strings = {
        param($Value)
        , @(@($Value) | Where-Object { $null -ne $_ -and [string]$_ -ne '' } | ForEach-Object { [string]$_ })
    }
    $adapters = @(foreach ($item in @($raw.Adapters | Where-Object { $null -ne $_ })) {
            $static = @((& $strings $item.DnsStaticIPv4) + (& $strings $item.DnsStaticIPv6))
            $ipv4 = & $strings $item.IPv4
            $gateways = & $strings $item.Gateways
            $dns = @((& $strings $item.DnsIPv4) + (& $strings $item.DnsIPv6))
            $statusText = Get-MwpNetAdapterStatusText -Status $item.Status
            $categoryText = switch ([string]$item.NetworkCategory) {
                'Private' { 'Prywatna' }
                'Public' { 'Publiczna' }
                'DomainAuthenticated' { 'Domenowa' }
                default { '' }
            }
            [pscustomobject]@{
                PSTypeName          = 'MWP.NetAdapter'
                InterfaceIndex      = [int]$item.InterfaceIndex
                InterfaceGuid       = [string]$item.InterfaceGuid
                Name                = [string]$item.Name
                Description         = [string]$item.Description
                Status              = [string]$item.Status
                StatusText          = $statusText
                IsEnabled           = [string]$item.Status -ne 'Disabled'
                MacAddress          = [string]$item.MacAddress
                LinkSpeed           = [string]$item.LinkSpeed
                MediaType           = [string]$item.MediaType
                Virtual             = [bool]$item.Virtual
                Hardware            = [bool]$item.Hardware
                IPv4                = $ipv4
                IPv6                = & $strings $item.IPv6
                HasIPv6             = [bool]$item.HasIPv6
                Gateways            = $gateways
                DnsServers          = $dns
                DnsStatic           = $static
                DnsMode             = $(if ($static.Count -gt 0) { 'Static' } else { 'Dhcp' })
                DnsText             = Format-MwpDnsServerText -Server $static
                DhcpEnabled         = [bool]$item.DhcpEnabled
                DhcpServer          = [string]$item.DhcpServer
                LeaseObtained       = ConvertFrom-MwpNetworkDate -Value $item.LeaseObtained
                LeaseExpires        = ConvertFrom-MwpNetworkDate -Value $item.LeaseExpires
                ProfileName         = [string]$item.ProfileName
                NetworkCategory     = [string]$item.NetworkCategory
                CategoryText        = $categoryText
                IPv4Connectivity    = [string]$item.IPv4Connectivity
                IsConnectionAdapter = [bool]$item.IsConnectionAdapter
                IPv4Text            = $ipv4 -join ', '
                GatewayText         = $gateways -join ', '
                DnsServersText      = $dns -join ', '
            }
        })
    $adapters = @($adapters | Sort-Object -Property @{ Expression = { $_.Status -ne 'Up' } }, @{ Expression = { $_.Virtual } }, Name)
    $collectedAt = ConvertFrom-MwpNetworkDate -Value $raw.CollectedAt
    $pending = @(foreach ($item in @($raw.Pending | Where-Object { $null -ne $_ })) {
            $adapter = @($adapters | Where-Object { $_.InterfaceIndex -eq [int]$item.InterfaceIndex }) | Select-Object -First 1
            [pscustomobject]@{
                PSTypeName       = 'MWP.NetworkPendingChange'
                ChangeId         = [string]$item.ChangeId
                TaskName         = [string]$item.TaskName
                Description      = [string]$item.Description
                State            = [string]$item.State
                Kind             = [string]$item.Kind
                InterfaceIndex   = [int]$item.InterfaceIndex
                AdapterName      = $(if ($null -ne $adapter) { $adapter.Name } else { '' })
                Deadline         = ConvertFrom-MwpNetworkDate -Value $item.Deadline
                RemainingSeconds = [int]$item.RemainingSeconds
                CollectedAt      = $collectedAt
            }
        })
    [pscustomobject]@{
        PSTypeName          = 'MWP.NetworkStatus'
        ComputerName        = [string]$raw.ComputerName
        CollectedAt         = $collectedAt
        IsAdministrator     = [bool]$raw.IsAdministrator
        Adapters            = $adapters
        Pending             = $pending
        ConnectionAddresses = & $strings $raw.ConnectionAddresses
        Warnings            = & $strings $raw.Warnings
    }
}
