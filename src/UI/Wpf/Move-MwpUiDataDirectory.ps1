function Move-MwpUiDataDirectory {
    <#
    .SYNOPSIS
        „Przenieś dane": podgląd (Move-MwpDataDirectory -WhatIf), potwierdzenie i przeniesienie w tle.

    .DESCRIPTION
        Klasa Zmiana (D-038): podgląd pokazuje katalog źródłowy i docelowy oraz liczbę plików logs,
        undo i modules. Przeniesienie (kopia, przełączenie dataPath, usunięcie starych danych) działa
        w zadaniu w tle; błąd nie zostawia danych w połowie (logika w MWP.Core).
    #>
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object] $Owner
    )

    $ui = $script:MwpUi
    $value = $ui.Views['settings'].Controls['DataPathBox'].Text.Trim()
    $preview = Move-MwpDataDirectory -DataPath $value -WhatIf
    if (-not $preview.IsPreview) {
        $null = Update-MwpDataPathPreview
        Show-MwpMessage -Text $preview.Message -Kind $(if ($preview.Success) { 'Info' } else { 'Warning' }) -Owner $Owner
        return
    }
    $lines = @($preview.Message) + @(@($preview.Data) | Where-Object { $null -ne $_ } | ForEach-Object { '{0}: {1} plików ({2})' -f $_.Name, $_.Files, $_.Path })
    $confirmed = Show-MwpConfirmDialog -Header 'Przeniesienie danych aplikacji' -Target 'Katalog danych: logi, rejestr cofnięć, moduły z paczek' `
        -PreviewLine $lines -Class Change -ConfirmText 'Przenieś' -Owner $Owner `
        -Warning 'Dane są najpierw kopiowane; stare usuwa się dopiero po zapisaniu nowego dataPath. Nowe położenie modułów z paczek obowiązuje w pełni po ponownym uruchomieniu aplikacji.'
    if (-not $confirmed) {
        return
    }
    $null = Start-MwpUiTask -Registry $ui.Tasks -Pool $ui.Pool -Name 'Przenoszenie danych' -ArgumentList @(, $value) -ScriptBlock {
        param($Progress, $DataPath)
        $Progress.Message = 'kopiowanie logs, undo i modules'
        Move-MwpDataDirectory -DataPath $DataPath -Confirm:$false
    } -OnCompleted {
        param($Task)
        $result = @($Task.Output | Where-Object { $_.PSObject.TypeNames -contains 'MWP.Result' }) | Select-Object -Last 1
        if ($null -eq $result) {
            Show-MwpMessage -Text ('Przeniesienie danych nie powiodło się: {0}' -f $Task.Error) -Kind Error
        }
        else {
            $text = if ($result.Success -and $result.Changed) { '{0}{1}{1}Uruchom aplikację ponownie, żeby moduły z paczek były odkrywane w nowym miejscu.' -f $result.Message, [Environment]::NewLine } else { $result.Message }
            Show-MwpMessage -Text $text -Kind $(if ($result.Success) { 'Info' } else { 'Warning' })
        }
        $settings = $script:MwpUi.Views['settings']
        if ($null -ne $settings) {
            Update-MwpSettingsView -View $settings
            $null = Update-MwpDataPathPreview
        }
    }
}
