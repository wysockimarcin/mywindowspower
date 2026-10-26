function Update-MwpDataPathPreview {
    <#
    .SYNOPSIS
        Pokazuje podgląd nowej wartości dataPath: ścieżkę wynikową, poprawność, zapisywalność i dane w miejscu docelowym.

    .DESCRIPTION
        Get-MwpDataLocation -DataPath niczego nie tworzy ani nie zapisuje (D-038). Zwraca obiekt podglądu.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Zmienia tylko kontrolki okna.')]
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $v = $script:MwpUi.Views['settings'].Controls
    $preview = Get-MwpDataLocation -DataPath $v['DataPathBox'].Text
    $yesNo = { param($Value) if ($Value) { 'tak' } else { 'nie' } }
    $v['DataPreviewText'].Text = if (-not $preview.IsValid) {
        $preview.Error
    }
    else {
        $lines = @(
            'Ścieżka wynikowa: {0}' -f $preview.Root
            'Istnieje: {0} · zapisywalny: {1} · bieżący katalog: {2} · są tam już dane aplikacji: {3}' -f (& $yesNo $preview.Exists), (& $yesNo $preview.Writable), (& $yesNo $preview.IsCurrent), (& $yesNo $preview.HasData)
        )
        if ($preview.Warning) {
            $lines += 'Uwaga: {0}' -f $preview.Warning
        }
        $lines -join [Environment]::NewLine
    }
    $preview
}
