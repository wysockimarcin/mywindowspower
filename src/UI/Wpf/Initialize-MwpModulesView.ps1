function Initialize-MwpModulesView {
    <#
    .SYNOPSIS
        Podpina widok „Moduły": instalacja z .mwpmod, odinstalowanie, przeniesienie dawnych instalacji, szczegóły.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '',
        Justification = 'Parametry obsługi zdarzeń WPF są używane w zagnieżdżonych blokach (Invoke-MwpUiSafe -Action), czego reguła nie widzi.')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $View
    )

    $v = $View.Controls
    $v['ModulesGrid'].Add_SelectionChanged({
            param($control)
            $controls = $script:MwpUi.Views['modules'].Controls
            $row = $control.SelectedItem
            $controls['UninstallButton'].IsEnabled = $null -ne $row -and $row.CanUninstall
            $controls['DetailsText'].Text = if ($null -eq $row) { 'Wybierz moduł, żeby zobaczyć szczegóły.' } else {
                $lines = @(
                    '{0} ({1}) · Id {2} · wersja {3} · {4}' -f $row.Name, $row.ModuleName, $row.Id, $row.Version, $row.Source
                    'Możliwości: {0} · tryby: {1} · uprawnienia: {2}' -f $(if ($row.Capabilities) { $row.Capabilities } else { '(brak)' }), $row.Modes, $row.Permissions
                    'Folder: {0}' -f $row.Path
                )
                if ($row.Sha256) {
                    $lines += 'Zainstalowano: {0} · SHA-256 paczki: {1}' -f $row.InstalledAt, $row.Sha256
                }
                if (-not $row.IsValid) {
                    $lines += $row.State
                }
                $lines -join [Environment]::NewLine
            }
        })
    $v['RefreshButton'].Add_Click({
            Invoke-MwpUiSafe -Name 'UI.Modules.Refresh' -Action { Update-MwpModuleCatalog }
        })
    $v['InstallButton'].Add_Click({
            param($control)
            Invoke-MwpUiSafe -Name 'UI.Modules.Install' -Action { Install-MwpUiModule -Owner (Get-MwpOwnerWindow -Element $control) }
        })
    $v['UninstallButton'].Add_Click({
            param($control)
            Invoke-MwpUiSafe -Name 'UI.Modules.Uninstall' -Action {
                $row = $script:MwpUi.Views['modules'].Controls['ModulesGrid'].SelectedItem
                if ($null -ne $row) { Uninstall-MwpUiModule -Row $row -Owner (Get-MwpOwnerWindow -Element $control) }
            }
        })
    $v['LegacyMoveButton'].Add_Click({
            param($control)
            Invoke-MwpUiSafe -Name 'UI.Modules.MoveLegacy' -Action { Move-MwpUiInstalledModule -Owner (Get-MwpOwnerWindow -Element $control) }
        })
}
