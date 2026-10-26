function Update-MwpSettingsView {
    <#
    .SYNOPSIS
        Odświeża Ustawienia: wybrany motyw, listę komputerów, bieżący katalog danych i ostrzeżenie o trybie zapasowym.
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
    $previous = $ui.Navigating
    $ui.Navigating = $true
    try {
        $v['ThemeCombo'].SelectedItem = @($v['ThemeCombo'].Items | Where-Object { [string]$_.Tag -eq $ui.ThemeSetting }) | Select-Object -First 1
    }
    finally {
        $ui.Navigating = $previous
    }

    $selected = $v['TargetsGrid'].SelectedItem
    $targets = @(Get-MwpTarget)
    $v['TargetsGrid'].ItemsSource = $targets
    if ($null -ne $selected) {
        $v['TargetsGrid'].SelectedItem = @($targets | Where-Object { $_.Name -eq $selected.Name }) | Select-Object -First 1
    }

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
