function Update-MwpSettingsView {
    <#
    .SYNOPSIS
        Odświeża Ustawienia: wybrany motyw, listę komputerów, bieżący katalog danych i ostrzeżenie o trybie zapasowym.

    .DESCRIPTION
        Lista komputerów (D-054): wiersze z Get-MwpTargetRow — kolumna „Nazwa” (localhost: nazwa hosta)
        i „Adres IP” (localhost: adres LAN odczytywany w tle, tylko informacyjnie; komputer zdalny: adres
        połączenia, w podpowiedzi adresy wykryte w otwartych połączeniach) oraz baner dla komputerów
        zapisanych pod adresem IP. -TargetsOnly odświeża tylko listę (po odczycie adresu LAN).
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Zmienia tylko kontrolki okna.')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $View,

        [switch] $TargetsOnly
    )

    $ui = $script:MwpUi
    $v = $View.Controls
    if ($TargetsOnly) {
        Update-MwpSettingsTargetList -View $View
        return
    }
    $previous = $ui.Navigating
    $ui.Navigating = $true
    try {
        $v['ThemeCombo'].SelectedItem = @($v['ThemeCombo'].Items | Where-Object { [string]$_.Tag -eq $ui.ThemeSetting }) | Select-Object -First 1
    }
    finally {
        $ui.Navigating = $previous
    }

    $storeSetting = Get-MwpSetting -Name 'remoteCredentialStore' -WarningAction SilentlyContinue
    $v['CredentialStoreCheck'].IsChecked = -not ($storeSetting -is [bool] -and -not $storeSetting)

    Update-MwpSettingsTargetList -View $View
    Start-MwpUiLocalAddressRead

    $location = Get-MwpDataLocation
    $v['CurrentDataText'].Text = "Bieżący katalog danych: {0}{4}Ustawienie dataPath: {1}{4}Logi: {2}{4}Cofnięcia: {3}{4}Moduły z paczek: {5}" -f
    $location.Root, $(if ($location.Configured) { "'{0}'" -f $location.Configured } else { '(puste — folder data obok aplikacji)' }),
    $location.Logs, $location.Undo, [Environment]::NewLine, $location.Modules
    if ($location.IsFallback) {
        $v['DataWarningText'].Text = 'Tryb zapasowy: {0}' -f $location.Warning
        $v['DataWarningBanner'].Visibility = 'Visible'
    }
    else {
        $v['DataWarningBanner'].Visibility = 'Collapsed'
    }
    Update-MwpStatusData
}
