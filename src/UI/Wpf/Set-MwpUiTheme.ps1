function Set-MwpUiTheme {
    <#
    .SYNOPSIS
        Przełącza motyw wszystkich okien aplikacji (podmiana słownika pędzli w zasobach aplikacji).

    .DESCRIPTION
        Style odwołują się do pędzli przez DynamicResource, więc podmiana słownika [0] w zasobach
        aplikacji zmienia wygląd otwartych okien bez ich ponownego tworzenia (D-004). Zapis ustawienia
        theme robi wywołujący (Set-MwpSetting) — tu tylko wygląd.

    .PARAMETER Theme
        Light albo Dark.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Zmienia tylko wygląd okien w pamięci procesu; nie zmienia stanu systemu.')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Light', 'Dark')]
        [string] $Theme
    )

    $ui = $script:MwpUi
    $dictionary = (Import-MwpXaml -Path (Join-Path -Path $ui.UiRoot -ChildPath ('Themes\{0}.xaml' -f $Theme))).Root
    $dictionaries = $ui.Application.Resources.MergedDictionaries
    if ($dictionaries.Count -gt 0) {
        $dictionaries[0] = $dictionary
    }
    else {
        $dictionaries.Insert(0, $dictionary)
    }
    $ui.Theme = $Theme

    $controls = $ui.Controls
    $settingText = switch ($ui.ThemeSetting) {
        'Light' { 'jasny' }
        'Dark' { 'ciemny' }
        default { 'zgodnie z systemem' }
    }
    $controls['ThemeLabel'].Text = 'Motyw: {0}' -f $settingText
    # Ikona pokazuje motyw, na który przełączy przycisk.
    $controls['ThemeGlyph'].Text = $(if ($Theme -eq 'Dark') { [string][char]0xE706 } else { [string][char]0xE708 })
}
