function Update-MwpModulesView {
    <#
    .SYNOPSIS
        Odświeża widok „Moduły": tabela (Get-MwpModuleRow), podsumowanie, baner dawnych instalacji (D-038).
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
    $selected = $v['ModulesGrid'].SelectedItem
    $rows = @(Get-MwpModuleRow -Definition $ui.Definitions -InstalledModule @(Get-MwpInstalledModule) -Instance @($ui.Instances.Values | ForEach-Object { $_.Instance }))
    $v['ModulesGrid'].ItemsSource = $rows
    if ($null -ne $selected) {
        $v['ModulesGrid'].SelectedItem = @($rows | Where-Object { $_.Id -eq $selected.Id }) | Select-Object -First 1
    }
    $installed = @($rows | Where-Object { $_.Source -eq 'Z paczki' }).Count
    $invalid = @($rows | Where-Object { -not $_.IsValid }).Count
    $location = Get-MwpDataLocation
    $v['Summary'].Text = 'Modułów: {0} (z paczek: {1}{2}). Moduły z paczek: {3}. Instalacja i odinstalowanie dotyczą tylko tego komputera; nowy moduł jest dostępny od razu w nawigacji.' -f
    $rows.Count, $installed, $(if ($invalid -gt 0) { ', z błędami kontraktu: {0}' -f $invalid } else { '' }), $location.Modules
    if (@($location.LegacyModules).Count -gt 0) {
        $v['LegacyText'].Text = 'Moduły z paczek w dawnym katalogu {0}: {1}. Od FAZY 4 moduły z paczek leżą w katalogu danych ({2}).' -f
        $location.LegacyPath, (@($location.LegacyModules) -join ', '), $location.Modules
        $v['LegacyBanner'].Visibility = 'Visible'
    }
    else {
        $v['LegacyBanner'].Visibility = 'Collapsed'
    }
}
