function Update-MwpSettingsTargetList {
    <#
    .SYNOPSIS
        Odświeża siatkę „Komputery docelowe” w Ustawieniach i baner komputerów zapisanych pod adresem IP (D-054).

    .DESCRIPTION
        Wiersze buduje Get-MwpTargetRow (bez WPF): adres LAN localhost ze stanu okna (odczyt w tle,
        Start-MwpUiLocalAddressRead), adresy wykryte — z połączeń otwartych instancji. Zaznaczenie
        wiersza jest zachowywane po nazwie komputera.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Zmienia tylko kontrolki okna.')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $View
    )

    $ui = $script:MwpUi
    $v = $View.Controls
    $localAddress = $null
    if ($ui.ContainsKey('LocalNetwork') -and $null -ne $ui.LocalNetwork) {
        $localAddress = $ui.LocalNetwork.Result
    }
    $detected = @{}
    foreach ($entry in @($ui.Instances.Values)) {
        $connection = $entry.Instance.Context.Connection
        if ($null -ne $connection.PSObject.Properties['DetectedAddresses'] -and @($connection.DetectedAddresses).Count -gt 0) {
            $detected[[string]$entry.Instance.Context.ComputerName] = @($connection.DetectedAddresses)
        }
    }

    $selected = $v['TargetsGrid'].SelectedItem
    $rows = @(Get-MwpTargetRow -Target @(Get-MwpTarget) -LocalAddress $localAddress -Detected $detected)
    $v['TargetsGrid'].ItemsSource = $rows
    if ($null -ne $selected) {
        $v['TargetsGrid'].SelectedItem = @($rows | Where-Object { $_.Name -eq $selected.Name }) | Select-Object -First 1
    }

    $unnamed = @($rows | Where-Object { $_.NeedsName })
    if ($unnamed.Count -gt 0) {
        $v['TargetNameText'].Text = ('Komputer zapisany pod adresem IP ({0}) — ustaw jego nazwę: aplikacja sprawdzi wtedy po połączeniu, czy pod adresem jest właściwy komputer, a widoki pokażą nazwę zamiast adresu.' -f
            (($unnamed | ForEach-Object { $_.Name }) -join ', '))
        $v['TargetNameButton'].Tag = $unnamed[0].Name
        $v['TargetNameBanner'].Visibility = 'Visible'
    }
    else {
        $v['TargetNameBanner'].Visibility = 'Collapsed'
    }
}
