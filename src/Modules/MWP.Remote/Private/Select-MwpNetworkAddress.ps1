function Select-MwpNetworkAddress {
    <#
    .SYNOPSIS
        Wybiera adres LAN komputera z surowych danych kart sieciowych (reguła D-054).

    .DESCRIPTION
        Reguła: adres IPv4 karty w stanie Up z bramą domyślną; przy kilku — ten, który system wybiera
        dla trasy domyślnej (PreferredAddress, czyli najniższa metryka), a gdy go brak — pierwszy
        z listy. Pomijane: karty pętli zwrotnej, adresy 127.0.0.0/8, APIPA 169.254.0.0/16, ::1
        i IPv6 link-local (fe80::/10). Pozostałe adresy kart w stanie Up (inne karty, IPv6) trafiają
        do OtherAddresses z nazwą karty. Status: Ok, NoNetwork („brak połączenia z siecią”) albo
        Unavailable („brak danych” — błąd odczytu). Funkcja czysta: niczego nie odczytuje ani nie zapisuje.
        Wynik jest wyłącznie informacyjny — nie trafia do ustawień, kontekstu wykonania ani adapterów.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [AllowNull()]
        [Collections.IDictionary] $Data
    )

    $result = [pscustomobject]@{
        PSTypeName     = 'MWP.NetworkAddress'
        Status         = 'Unavailable'
        PrimaryAddress = $null
        InterfaceName  = $null
        OtherAddresses = @()
        AllAddresses   = @()
        Text           = 'brak danych'
        ToolTip        = ''
        Warnings       = @()
    }
    $interfaces = @()
    if ($null -ne $Data -and $Data.Contains('Interfaces') -and $null -ne $Data['Interfaces']) {
        $interfaces = @($Data['Interfaces'] | Where-Object { $_ -is [Collections.IDictionary] })
    }
    $readError = if ($null -ne $Data -and $Data.Contains('Error')) { [string]$Data['Error'] } else { '' }
    if ($null -eq $Data -or ($interfaces.Count -eq 0 -and $readError -ne '')) {
        $warning = if ($readError -ne '') { 'Nie udało się odczytać kart sieciowych: {0}' -f $readError } else { 'Brak danych o kartach sieciowych.' }
        $result.Warnings = @($warning)
        $result.ToolTip = $warning
        return $result
    }
    if ($readError -ne '') {
        $result.Warnings = @('Odczyt kart sieciowych zgłosił błąd: {0}' -f $readError)
    }

    $isUsable = {
        param([string] $Address, [string] $Family)
        if ($Family -eq 'IPv4') {
            return -not ($Address -like '127.*' -or $Address -like '169.254.*')
        }
        -not ($Address -eq '::1' -or $Address -match '^fe[89ab][0-9a-f]:')
    }

    $candidates = New-Object -TypeName System.Collections.Generic.List[object]
    $all = New-Object -TypeName System.Collections.Generic.List[object]
    foreach ($interface in $interfaces) {
        if ([string]$interface['Status'] -ne 'Up' -or [string]$interface['Type'] -eq 'Loopback') {
            continue
        }
        foreach ($entry in @($interface['Addresses'] | Where-Object { $_ -is [Collections.IDictionary] })) {
            $address = [string]$entry['Address']
            $family = [string]$entry['Family']
            if ($address -eq '' -or -not (& $isUsable $address $family)) {
                continue
            }
            $item = [pscustomobject]@{ Address = $address; Family = $family; InterfaceName = [string]$interface['Name'] }
            $all.Add($item)
            if ($family -eq 'IPv4' -and [bool]$interface['HasGateway']) {
                $candidates.Add($item)
            }
        }
    }

    $preferred = if ($Data.Contains('PreferredAddress')) { [string]$Data['PreferredAddress'] } else { '' }
    $primary = @($candidates | Where-Object { $_.Address -eq $preferred }) | Select-Object -First 1
    if ($null -eq $primary) {
        $primary = $candidates | Select-Object -First 1
    }

    if ($null -eq $primary) {
        $result.Status = 'NoNetwork'
        $result.Text = 'brak połączenia z siecią'
        $result.OtherAddresses = $all.ToArray()
        $result.AllAddresses = @($all | ForEach-Object { $_.Address })
    }
    else {
        $result.Status = 'Ok'
        $result.PrimaryAddress = $primary.Address
        $result.InterfaceName = $primary.InterfaceName
        $result.Text = $primary.Address
        $result.OtherAddresses = @($all | Where-Object { -not [object]::ReferenceEquals($_, $primary) })
        $result.AllAddresses = @(@($primary.Address) + @($result.OtherAddresses | ForEach-Object { $_.Address }))
    }

    $lines = New-Object -TypeName System.Collections.Generic.List[string]
    if ($null -ne $primary) {
        $lines.Add(('Karta: {0}' -f $primary.InterfaceName))
    }
    if (@($result.OtherAddresses).Count -gt 0) {
        $lines.Add('Inne adresy:')
        foreach ($other in $result.OtherAddresses) {
            $lines.Add(('  {0} ({1}, {2})' -f $other.Address, $other.InterfaceName, $other.Family))
        }
    }
    foreach ($warning in $result.Warnings) {
        $lines.Add($warning)
    }
    $result.ToolTip = $lines -join [Environment]::NewLine
    $result
}
