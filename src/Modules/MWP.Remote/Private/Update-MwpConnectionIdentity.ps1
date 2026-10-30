function Update-MwpConnectionIdentity {
    <#
    .SYNOPSIS
        Zapisuje w obiekcie połączenia tożsamość odczytaną z komputera zdalnego i zwraca wynik porównania nazw.

    .DESCRIPTION
        D-054: ustawia RemoteComputerName, NameVerified ($true zgodna, $false NameMismatch, $null bez
        weryfikacji — nazwa w rejestrze jest adresem IP albo tożsamości nie udało się odczytać),
        DetectedAddresses (adresy LAN zgłoszone przez komputer; reguła Select-MwpNetworkAddress,
        adres główny pierwszy) i AddressWarning — ostrzeżenie (bez blokady), gdy adres połączenia jest
        adresem IPv4 spoza adresów wykrytych (np. NAT, przekierowanie portu). Zwraca NameVerified.
        -RemoteName zastępuje słownik tożsamości, gdy znana jest tylko nazwa (odczyt przez CIM).
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Zmienia tylko obiekt połączenia w pamięci.')]
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory)]
        [PSTypeName('MWP.ExecutionContext')]
        [object] $Context,

        [AllowNull()]
        [Collections.IDictionary] $Identity,

        [AllowEmptyString()]
        [string] $RemoteName = ''
    )

    $connection = $Context.Connection
    $names = @()
    $detected = @()
    if ($null -ne $Identity) {
        $names = @([string]$Identity['ComputerName'], [string]$Identity['HostName'])
        if ($Identity.Contains('Network') -and $Identity['Network'] -is [Collections.IDictionary]) {
            $detected = @((Select-MwpNetworkAddress -Data $Identity['Network']).AllAddresses)
        }
    }
    elseif ($RemoteName -ne '') {
        $names = @($RemoteName)
    }
    $reported = @($names | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) | Select-Object -First 1
    $verified = Test-MwpRemoteNameMatch -Name $Context.ComputerName -RemoteNames $names

    $warning = $null
    $address = [string]$Context.Address
    if ((Test-MwpIPv4Address -Value $address) -and $detected.Count -gt 0 -and $detected -notcontains $address) {
        $warning = "Adres '{0}' nie jest wśród adresów zgłoszonych przez komputer '{1}' ({2}) — np. NAT albo przekierowanie portu." -f $address, $Context.ComputerName, ($detected -join ', ')
    }
    foreach ($property in 'RemoteComputerName', 'DetectedAddresses', 'NameVerified', 'AddressWarning') {
        if ($null -eq $connection.PSObject.Properties[$property]) {
            $connection | Add-Member -NotePropertyName $property -NotePropertyValue $null
        }
    }
    $connection.RemoteComputerName = $reported
    if ($null -ne $Identity) {
        $connection.DetectedAddresses = $detected
        $connection.AddressWarning = $warning
    }
    $connection.NameVerified = $verified
    $verified
}
