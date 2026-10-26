function Move-MwpUiInstalledModule {
    <#
    .SYNOPSIS
        Przenosi moduły z paczek z dawnego src\Modules\Installed do katalogu danych (podgląd, potwierdzenie, w tle).
    #>
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object] $Owner
    )

    $ui = $script:MwpUi
    $preview = Move-MwpInstalledModule -WhatIf
    if (-not $preview.IsPreview) {
        Show-MwpMessage -Text $preview.Message -Owner $Owner
        return
    }
    $confirmed = Show-MwpConfirmDialog -Header 'Przeniesienie modułów z paczek' -Target 'Moduły z paczek: src\Modules\Installed -> katalog danych' `
        -PreviewLine @(ConvertTo-MwpPreviewLine -Result $preview) -Class Change -ConfirmText 'Przenieś' -Owner $Owner `
        -Warning 'Załadowane moduły działają dalej; nowe położenie obowiązuje od następnego uruchomienia aplikacji.'
    if (-not $confirmed) {
        return
    }
    $null = Start-MwpUiTask -Registry $ui.Tasks -Pool $ui.Pool -Name 'Przenoszenie modułów z paczek' -State @{ Owner = $Owner } -ScriptBlock {
        param($Progress)
        $Progress.Message = 'kopiowanie modułów'
        Move-MwpInstalledModule -Confirm:$false
    } -OnCompleted {
        param($Task)
        $result = @($Task.Output | Where-Object { $_.PSObject.TypeNames -contains 'MWP.Result' }) | Select-Object -Last 1
        $text = if ($null -eq $result) { 'Przeniesienie nie powiodło się: {0}' -f $Task.Error } else { $result.Message }
        Update-MwpModuleCatalog
        Show-MwpMessage -Text $text -Kind $(if ($null -ne $result -and $result.Success) { 'Info' } else { 'Warning' }) -Owner $Task.State.Owner
    }
}
