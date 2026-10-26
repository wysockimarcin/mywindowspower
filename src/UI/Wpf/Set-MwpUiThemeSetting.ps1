function Set-MwpUiThemeSetting {
    <#
    .SYNOPSIS
        Zapisuje ustawienie motywu (System, Light, Dark) i przełącza wygląd okien.

    .DESCRIPTION
        Ustawienie aplikacji (nie zmiana systemu): Set-MwpSetting z logiem i wpisem cofnięcia, bez
        okna potwierdzenia. Błąd zapisu nie blokuje zmiany wyglądu w bieżącej sesji (komunikat).
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('System', 'Light', 'Dark')]
        [string] $Setting
    )

    $ui = $script:MwpUi
    if (-not $PSCmdlet.ShouldProcess('ustawienie theme', ("Zmiana na '{0}'" -f $Setting))) {
        return
    }
    $result = Set-MwpSetting -Name 'theme' -Value $Setting -Confirm:$false
    if (-not $result.Success) {
        Show-MwpMessage -Text ("Nie zapisano ustawienia motywu: {0}" -f $result.Message) -Kind Warning
    }
    $ui.ThemeSetting = $Setting
    Set-MwpUiTheme -Theme (Resolve-MwpThemeName -Setting $Setting -SystemTheme (Get-MwpSystemTheme))
    $settings = $ui.Views['settings']
    if ($null -ne $settings) {
        Update-MwpSettingsView -View $settings
    }
}
