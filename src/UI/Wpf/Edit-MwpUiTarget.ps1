function Edit-MwpUiTarget {
    <#
    .SYNOPSIS
        Dodaje albo zmienia komputer docelowy: formularz, podgląd (-WhatIf), potwierdzenie, zapis.

    .DESCRIPTION
        Zapis i walidacja należą do MWP.Remote (Add-MwpTarget, Set-MwpTarget: log, wpis cofnięcia);
        okno tylko zbiera dane i pokazuje podgląd. Hasło nie jest zbierane ani zapisywane (D-034).

    .PARAMETER Target
        Komputer do edycji; bez niego — dodanie nowego.
    #>
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object] $Target,

        [AllowNull()]
        [object] $Owner
    )

    $parameters = Show-MwpTargetEditor -Target $Target -Owner $Owner
    if ($null -eq $parameters) {
        return
    }
    $isEdit = $null -ne $Target
    $command = if ($isEdit) { 'Set-MwpTarget' } else { 'Add-MwpTarget' }
    $preview = & $command @parameters -WhatIf
    if (-not $preview.IsPreview) {
        $text = if ($preview.Success) { $preview.Message } else { 'Nie można zapisać: {0}' -f $preview.Message }
        Show-MwpMessage -Text $text -Kind $(if ($preview.Success) { 'Info' } else { 'Warning' }) -Owner $Owner
        return
    }
    $header = if ($isEdit) { 'Zmiana komputera docelowego' } else { 'Dodanie komputera docelowego' }
    $confirmed = Show-MwpConfirmDialog -Header $header -Target ("Rejestr komputerów docelowych (config\settings.local.json): {0}" -f $parameters.Name) `
        -PreviewLine @(ConvertTo-MwpPreviewLine -Result $preview) -Class Change -Owner $Owner `
        -Warning 'Aplikacja nie zmienia konfiguracji WinRM ani TrustedHosts; wpis TrustedHosts dla grupy roboczej wykonujesz ręcznie.'
    if (-not $confirmed) {
        return
    }
    $result = & $command @parameters -Confirm:$false
    if (-not $result.Success) {
        Show-MwpMessage -Text $result.Message -Kind Warning -Owner $Owner
    }
    Update-MwpCurrentView
}
