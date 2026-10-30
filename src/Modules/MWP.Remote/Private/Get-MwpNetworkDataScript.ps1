function Get-MwpNetworkDataScript {
    <#
    .SYNOPSIS
        Zwraca samowystarczalny blok skryptu odczytujący karty sieciowe i ich adresy (lokalnie albo na komputerze zdalnym).

    .DESCRIPTION
        D-054: ten sam blok działa na komputerze aplikacji (Get-MwpLocalNetworkAddress) i w sesji
        zdalnej (Get-MwpRemoteIdentity, Test-MwpTarget), więc jest zgodny z Windows PowerShell 5.1
        (D-036) i używa tylko .NET System.Net.NetworkInformation — bez CIM/WMI, bez uprawnień
        administratora i bez zmian w systemie. Zwraca surowe dane: Interfaces (Name, Description,
        Type, Status, HasGateway — brama domyślna IPv4, Addresses z rodziną) i PreferredAddress —
        adres źródłowy, który system wybrałby dla trasy domyślnej (gniazdo UDP „połączone” z adresem
        dokumentacyjnym 192.0.2.1: bez wysyłania pakietów, wybór według metryk tras). Regułę wyboru
        adresu stosuje Select-MwpNetworkAddress po stronie aplikacji. Błąd odczytu trafia do pola Error.
    #>
    [CmdletBinding()]
    [OutputType([scriptblock])]
    param()

    {
        $result = @{ Interfaces = @(); PreferredAddress = $null; Error = $null }
        try {
            $list = foreach ($nic in [System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces()) {
                $properties = $nic.GetIPProperties()
                $gateways = @($properties.GatewayAddresses | Where-Object {
                        $_.Address.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork -and $_.Address.ToString() -ne '0.0.0.0'
                    })
                $addresses = foreach ($unicast in $properties.UnicastAddresses) {
                    $family = if ($unicast.Address.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork) { 'IPv4' } else { 'IPv6' }
                    @{ Address = $unicast.Address.ToString(); Family = $family }
                }
                @{
                    Name        = $nic.Name
                    Description = $nic.Description
                    Type        = $nic.NetworkInterfaceType.ToString()
                    Status      = $nic.OperationalStatus.ToString()
                    HasGateway  = $gateways.Count -gt 0
                    Addresses   = @($addresses)
                }
            }
            $result.Interfaces = @($list)
        }
        catch {
            $result.Error = $_.Exception.Message
        }
        try {
            $socket = New-Object -TypeName System.Net.Sockets.Socket -ArgumentList ([System.Net.Sockets.AddressFamily]::InterNetwork), ([System.Net.Sockets.SocketType]::Dgram), ([System.Net.Sockets.ProtocolType]::Udp)
            try {
                $socket.Connect('192.0.2.1', 9)
                $result.PreferredAddress = $socket.LocalEndPoint.Address.ToString()
            }
            finally {
                $socket.Close()
            }
        }
        catch {
            $result.PreferredAddress = $null
        }
        $result
    }
}
