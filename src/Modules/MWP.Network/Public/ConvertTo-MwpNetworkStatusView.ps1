function ConvertTo-MwpNetworkStatusView {
    <#
    .SYNOPSIS
        Zamienia stan sieci na widok widgetu „Sieć” (MWP.WidgetView): adaptery z adresami, bramą, DNS i trybem DHCP.

    .DESCRIPTION
        Funkcja widoku z kontraktu widgetu (D-043, D-053): czysta, bez WPF i bez wywołań systemowych.
        Przyjmuje wynik Get-MwpNetworkStatus (także surowy wynik operacji w tle). Jedna sekcja na
        adapter; parametr OnlyConnected (domyślnie $true) pomija adaptery bez połączenia, a Details
        wybiera wiersze: IPv4, Gateway, Dns, Dhcp, IPv6 (domyślnie tylko IPv4 — minimum miejsca).
        Zmiany czekające na zatwierdzenie (automatyczne wycofanie, D-049) są ostrzeżeniem. Zwraca $null,
        gdy danych nie ma.

    .PARAMETER WidgetParameters
        Parametry widgetu: OnlyConnected (bool), Details (lista wierszy).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [AllowNull()]
        [object] $Data,

        [AllowNull()]
        [Collections.IDictionary] $WidgetParameters
    )

    $status = Resolve-MwpNetworkStatus -Data $Data
    if ($null -eq $status) {
        return $null
    }
    $onlyConnected = $true
    $details = @('IPv4')
    if ($null -ne $WidgetParameters) {
        if ($WidgetParameters.Contains('OnlyConnected') -and $null -ne $WidgetParameters['OnlyConnected']) {
            $onlyConnected = [bool]$WidgetParameters['OnlyConnected']
        }
        if ($WidgetParameters.Contains('Details')) {
            $details = @(@($WidgetParameters['Details']) | Where-Object { @('IPv4', 'Gateway', 'Dns', 'Dhcp', 'IPv6') -contains $_ })
        }
    }
    $row = {
        param([string] $Label, [string] $Value, [string] $Tone = 'Neutral')
        [pscustomobject]@{ Label = $Label; Value = $(if ($Value) { $Value } else { 'brak danych' }); Percent = -1; Tone = $Tone }
    }
    $adapters = @($status.Adapters)
    $connected = @($adapters | Where-Object { $_.Status -eq 'Up' })
    $shown = if ($onlyConnected) { $connected } else { $adapters }
    $sections = @(foreach ($adapter in $shown) {
            $tone = if ($adapter.Status -eq 'Up') { 'Success' } elseif (-not $adapter.IsEnabled) { 'Neutral' } else { 'Warning' }
            $items = @(& $row 'Stan' $(if ($adapter.LinkSpeed -and $adapter.Status -eq 'Up') { '{0} · {1}' -f $adapter.StatusText, $adapter.LinkSpeed } else { $adapter.StatusText }) $tone)
            if ($details -contains 'IPv4') {
                $items += & $row 'IPv4' $adapter.IPv4Text
            }
            if ($details -contains 'Gateway') {
                $items += & $row 'Brama' $adapter.GatewayText
            }
            if ($details -contains 'Dns') {
                $items += & $row 'DNS' $(if ($adapter.DnsServersText) { '{0} ({1})' -f $adapter.DnsServersText, $(if ($adapter.DnsMode -eq 'Static') { 'statyczne' } else { 'z DHCP' }) } else { $null })
            }
            if ($details -contains 'Dhcp') {
                $items += & $row 'Adres IP' $(if ($adapter.DhcpEnabled) { 'z DHCP' } else { 'statyczny' })
            }
            if ($details -contains 'IPv6') {
                $items += & $row 'IPv6' $(if (@($adapter.IPv6).Count -gt 0) { @($adapter.IPv6) -join ', ' } else { 'brak' })
            }
            $title = $adapter.Name
            if ($adapter.IsConnectionAdapter) {
                $title = '{0} (połączenie zdalne)' -f $title
            }
            [pscustomobject]@{ Title = $title; Items = $items }
        })
    if ($sections.Count -eq 0) {
        $sections = @([pscustomobject]@{ Title = 'Adaptery'; Items = @(& $row 'Połączone' 'brak połączonych adapterów' 'Warning') })
    }
    $warnings = @($status.Warnings)
    foreach ($change in @($status.Pending)) {
        $warnings += 'Zmiana czeka na zatwierdzenie: {0} (adapter {1}).' -f $change.Description, $change.AdapterName
    }
    [pscustomobject]@{
        PSTypeName  = 'MWP.WidgetView'
        Summary     = '{0} · połączone adaptery: {1} z {2}' -f $status.ComputerName, $connected.Count, $adapters.Count
        CollectedAt = $status.CollectedAt
        Sections    = $sections
        Warnings    = $warnings
    }
}
