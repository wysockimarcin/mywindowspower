function Initialize-MwpSettingsView {
    <#
    .SYNOPSIS
        Podpina widok Ustawień: motyw, komputery docelowe, katalog danych (dataPath, „Przenieś dane").

    .DESCRIPTION
        Każda zmiana: podgląd przez funkcję logiki z -WhatIf, okno potwierdzenia, wykonanie
        (długie — w tle). Logika katalogu danych jest w MWP.Core (Get-MwpDataLocation,
        Move-MwpDataDirectory, Set-MwpSetting), nie w kodzie widoku (D-032, D-038).
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '',
        Justification = 'Parametry obsługi zdarzeń WPF są używane w zagnieżdżonych blokach (Invoke-MwpUiSafe -Action), czego reguła nie widzi.')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $View
    )

    $v = $View.Controls
    $v['ThemeCombo'].Add_SelectionChanged({
            param($control)
            Invoke-MwpUiSafe -Name 'UI.Settings.Theme' -Action {
                $ui = $script:MwpUi
                $selected = $control.SelectedItem
                if ($ui.Navigating -or $null -eq $selected -or [string]$selected.Tag -eq $ui.ThemeSetting) {
                    return
                }
                Set-MwpUiThemeSetting -Setting ([string]$selected.Tag)
            }
        })

    $v['CredentialStoreCheck'].Add_Click({
            param($control)
            Invoke-MwpUiSafe -Name 'UI.Settings.CredentialStore' -Action {
                # D-052: przełącznik globalny; Set-MwpSetting zapisuje atomowo, z logiem i wpisem cofnięcia.
                $result = Set-MwpSetting -Name 'remoteCredentialStore' -Value ([bool]$control.IsChecked) -Confirm:$false
                if (-not $result.Success) {
                    Show-MwpMessage -Text $result.Message -Kind Warning -Owner (Get-MwpOwnerWindow -Element $control)
                    Update-MwpCurrentView
                }
            }
        })

    $v['TargetsGrid'].Add_SelectionChanged({
            param($control)
            $controls = $script:MwpUi.Views['settings'].Controls
            $target = $control.SelectedItem
            $editable = $null -ne $target -and -not $target.IsLocal
            $controls['EditTargetButton'].IsEnabled = $editable
            $controls['RemoveTargetButton'].IsEnabled = $editable
            $controls['TestTargetButton'].IsEnabled = $null -ne $target
        })
    $v['AddTargetButton'].Add_Click({
            param($control)
            Invoke-MwpUiSafe -Name 'UI.Target.Add' -Action { Edit-MwpUiTarget -Owner (Get-MwpOwnerWindow -Element $control) }
        })
    $v['EditTargetButton'].Add_Click({
            param($control)
            Invoke-MwpUiSafe -Name 'UI.Target.Edit' -Action {
                $target = $script:MwpUi.Views['settings'].Controls['TargetsGrid'].SelectedItem
                if ($null -ne $target) { Edit-MwpUiTarget -Target $target -Owner (Get-MwpOwnerWindow -Element $control) }
            }
        })
    $v['RemoveTargetButton'].Add_Click({
            param($control)
            Invoke-MwpUiSafe -Name 'UI.Target.Remove' -Action {
                $target = $script:MwpUi.Views['settings'].Controls['TargetsGrid'].SelectedItem
                if ($null -ne $target) { Remove-MwpUiTarget -Target $target -Owner (Get-MwpOwnerWindow -Element $control) -Confirm:$false }
            }
        })
    $v['TestTargetButton'].Add_Click({
            param($control)
            Invoke-MwpUiSafe -Name 'UI.Target.Test' -Action {
                $controls = $script:MwpUi.Views['settings'].Controls
                $target = $controls['TargetsGrid'].SelectedItem
                if ($null -eq $target) {
                    return
                }
                $controls['TargetTestText'].Text = "Diagnostyka komputera '{0}' w toku…" -f (Format-MwpTargetLabel -ComputerName $target.Name)
                Invoke-MwpUiTargetTest -Target $target -Owner (Get-MwpOwnerWindow -Element $control) -OnResult {
                    param($Text)
                    $script:MwpUi.Views['settings'].Controls['TargetTestText'].Text = $Text
                }
            }
        })

    # D-054: „Odśwież” — ponowny odczyt adresu LAN tego komputera (tylko informacyjnie) i listy komputerów.
    $v['RefreshTargetsButton'].Add_Click({
            Invoke-MwpUiSafe -Name 'UI.Target.Refresh' -Action {
                Start-MwpUiLocalAddressRead -Force
                Update-MwpSettingsTargetList -View $script:MwpUi.Views['settings']
            }
        })
    # D-054: baner „Komputer zapisany pod adresem IP — ustaw nazwę” otwiera edytor tego komputera.
    $v['TargetNameButton'].Add_Click({
            param($control)
            Invoke-MwpUiSafe -Name 'UI.Target.SetName' -Action {
                $name = [string]$control.Tag
                $target = @(Get-MwpTarget | Where-Object { $_.Name -eq $name }) | Select-Object -First 1
                if ($null -ne $target) { Edit-MwpUiTarget -Target $target -Owner (Get-MwpOwnerWindow -Element $control) }
            }
        })

    $v['CheckDataPathButton'].Add_Click({
            Invoke-MwpUiSafe -Name 'UI.DataPath.Check' -Action { Update-MwpDataPathPreview }
        })
    $v['DataPathBox'].Add_KeyDown({
            param($control, $eventData)
            if ($eventData.Key -eq 'Return') {
                Invoke-MwpUiSafe -Name 'UI.DataPath.Check' -Action { Update-MwpDataPathPreview }
            }
        })
    $v['MoveDataButton'].Add_Click({
            param($control)
            Invoke-MwpUiSafe -Name 'UI.DataPath.Move' -Action { Move-MwpUiDataDirectory -Owner (Get-MwpOwnerWindow -Element $control) }
        })
    $v['SaveDataPathButton'].Add_Click({
            param($control)
            Invoke-MwpUiSafe -Name 'UI.DataPath.Save' -Action { Save-MwpUiDataPath -Owner (Get-MwpOwnerWindow -Element $control) }
        })

    $v['DataPathBox'].Text = [string](Get-MwpDataLocation).Configured
}
