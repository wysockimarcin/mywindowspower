function Get-MwpLocalNetworkAddress {
    <#
    .SYNOPSIS
        Zwraca adres tego komputera w sieci LAN — wyłącznie informacyjnie (kolumna „Adres IP” wiersza localhost).

    .DESCRIPTION
        D-054: odczyt przez .NET System.Net.NetworkInformation (5.1 i 7.x, bez CIM/WMI, bez
        administratora, bez zmian w systemie) i reguła Select-MwpNetworkAddress: IPv4 karty w stanie
        Up z bramą domyślną, przy kilku — trasa domyślna o najniższej metryce; pomijane pętla zwrotna
        i APIPA. Wynik: PrimaryAddress, InterfaceName, OtherAddresses (z nazwą karty i rodziną),
        AllAddresses, Status (Ok | NoNetwork | Unavailable), Text, ToolTip, Warnings. Błąd odczytu
        daje Status Unavailable („brak danych”), nigdy wyjątek.
        Adres nie jest zapisywany (zmienia się przy DHCP) i aplikacja nigdy nie używa go do łączenia
        ani do operacji: localhost działa lokalnie (tryb Local, bez WinRM i bez sieci). Funkcja jest
        wywoływana tylko przy wyświetleniu (Ustawienia → Komputery docelowe, „Odśwież”), poza wątkiem UI.

    .EXAMPLE
        (Get-MwpLocalNetworkAddress).Text
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $data = $null
    try {
        $data = & (Get-MwpNetworkDataScript)
    }
    catch {
        $data = @{ Interfaces = @(); PreferredAddress = $null; Error = $_.Exception.Message }
    }
    Select-MwpNetworkAddress -Data $data
}
