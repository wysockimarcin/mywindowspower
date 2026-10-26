function Save-MwpUiDataPath {
    <#
    .SYNOPSIS
        Zapisuje nową wartość dataPath bez przenoszenia danych (podgląd, ostrzeżenie, potwierdzenie).

    .DESCRIPTION
        Set-MwpSetting (log, wpis cofnięcia). Dotychczasowe logi, cofnięcia i moduły z paczek zostają
        w starym katalogu i nie są widoczne z nowego (D-032) — stąd ostrzeżenie w oknie potwierdzenia.
    #>
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object] $Owner
    )

    $value = $script:MwpUi.Views['settings'].Controls['DataPathBox'].Text.Trim()
    $check = Update-MwpDataPathPreview
    if (-not $check.IsValid) {
        Show-MwpMessage -Text $check.Error -Kind Warning -Owner $Owner
        return
    }
    $preview = Set-MwpSetting -Name 'dataPath' -Value $value -WhatIf
    if (-not $preview.IsPreview) {
        Show-MwpMessage -Text $preview.Message -Kind Warning -Owner $Owner
        return
    }
    $warning = 'Dane NIE zostaną przeniesione: logi, rejestr cofnięć i moduły z paczek zostaną w {0} i nie będą widoczne z nowego katalogu. Do przeniesienia służy „Przenieś dane”.' -f (Get-MwpDataLocation).Root
    if (-not $check.Writable) {
        $warning = '{0} {1}' -f $warning, $check.Warning
    }
    $lines = @(ConvertTo-MwpPreviewLine -Result $preview) + ('Ścieżka wynikowa: {0}' -f $check.Root)
    $confirmed = Show-MwpConfirmDialog -Header 'Zmiana katalogu danych (bez przenoszenia)' -Target "Ustawienie dataPath" `
        -PreviewLine $lines -Class Change -Warning $warning -ConfirmText 'Zapisz' -Owner $Owner
    if (-not $confirmed) {
        return
    }
    $result = Set-MwpSetting -Name 'dataPath' -Value $value -Confirm:$false
    Show-MwpMessage -Text $result.Message -Kind $(if ($result.Success) { 'Info' } else { 'Warning' }) -Owner $Owner
    Update-MwpSettingsView -View $script:MwpUi.Views['settings']
}
