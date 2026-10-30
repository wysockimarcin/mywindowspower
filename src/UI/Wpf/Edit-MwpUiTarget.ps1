function Edit-MwpUiTarget {
    <#
    .SYNOPSIS
        Dodaje albo zmienia komputer docelowy: formularz, podgląd (-WhatIf), potwierdzenie, zapis.

    .DESCRIPTION
        Zapis i walidacja należą do MWP.Remote (Add-MwpTarget, Set-MwpTarget: log, wpis cofnięcia);
        okno tylko zbiera dane i pokazuje podgląd. Hasło nie jest zbierane ani zapisywane (D-034).
        Zmiana nazwy (D-054, Set-MwpTarget -NewName): instancje modułów tego komputera trzeba najpierw
        zamknąć (okno o tym informuje); widgety Pulpitu tego komputera są na czas zmiany zamykane
        i odtwarzane pod nową nazwą (ich konfigurację przepisuje Set-MwpTarget), także gdy zmiana się
        nie uda — wtedy pod starą nazwą.

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

    $ui = $script:MwpUi
    $parameters = Show-MwpTargetEditor -Target $Target -Owner $Owner
    if ($null -eq $parameters) {
        return
    }
    $isEdit = $null -ne $Target
    $renaming = $isEdit -and $parameters.ContainsKey('NewName')
    if ($renaming) {
        $open = @($ui.Instances.Values | Where-Object { $_.Instance.Context.ComputerName -eq $Target.Name })
        if ($open.Count -gt 0) {
            Show-MwpMessage -Kind Warning -Owner $Owner -Text ("Zmiana nazwy komputera {0} wymaga zamknięcia jego instancji ({1}): {2}." -f $Target.Name, $open.Count,
                (($open | ForEach-Object { $_.Instance.Name }) -join ', '))
            return
        }
    }
    $command = if ($isEdit) { 'Set-MwpTarget' } else { 'Add-MwpTarget' }
    $preview = & $command @parameters -WhatIf
    if (-not $preview.IsPreview) {
        $text = if ($preview.Success) { $preview.Message } else { 'Nie można zapisać: {0}' -f $preview.Message }
        Show-MwpMessage -Text $text -Kind $(if ($preview.Success) { 'Info' } else { 'Warning' }) -Owner $Owner
        return
    }
    $header = if ($renaming) { 'Zmiana nazwy komputera docelowego' } elseif ($isEdit) { 'Zmiana komputera docelowego' } else { 'Dodanie komputera docelowego' }
    $warning = 'Aplikacja nie zmienia konfiguracji WinRM ani TrustedHosts; wpis TrustedHosts dla grupy roboczej wykonujesz ręcznie (przy łączeniu po adresie IP — adres IP).'
    if ($renaming) {
        $warning = 'Zapisane hasło, widgety Pulpitu i wpisy cofnięcia przejdą na nową nazwę; widgety tego komputera zostaną na chwilę zamknięte i odtworzone. Po połączeniu aplikacja sprawdzi, że komputer zgłasza nową nazwę. {0}' -f $warning
    }
    $confirmed = Show-MwpConfirmDialog -Header $header -Target ("Rejestr komputerów docelowych (config\settings.local.json): {0}" -f $(if ($renaming) { '{0} → {1}' -f $parameters.Name, $parameters.NewName } else { $parameters.Name })) `
        -PreviewLine @(ConvertTo-MwpPreviewLine -Result $preview) -Class Change -Owner $Owner -Warning $warning
    if (-not $confirmed) {
        return
    }

    # Widgety komputera mają instancje ze starą nazwą: zamknij je na czas zmiany, potem odtwórz z bieżącej konfiguracji.
    $closed = @()
    if ($renaming -and $null -ne $ui.Dashboard) {
        $closed = @($ui.Dashboard.Widgets | Where-Object { -not $_.Removed -and [string]$_.Config['computerName'] -eq $Target.Name })
        foreach ($widget in $closed) {
            Remove-MwpWidgetRuntime -Widget $widget -Confirm:$false
        }
    }
    $result = & $command @parameters -Confirm:$false
    if ($closed.Count -gt 0) {
        $newName = if ($result.Success) { [string]$parameters.NewName } else { [string]$Target.Name }
        foreach ($widget in $closed) {
            $index = $ui.Dashboard.Widgets.IndexOf($widget)
            $configuration = [ordered]@{}
            foreach ($key in $widget.Config.Keys) {
                $configuration[$key] = $widget.Config[$key]
            }
            $configuration['computerName'] = $newName
            $runtime = New-MwpWidgetRuntime -Configuration $configuration -Definition $widget.Definition
            if ($index -ge 0) {
                $ui.Dashboard.Widgets[$index] = $runtime
            }
            else {
                $ui.Dashboard.Widgets.Add($runtime)
            }
        }
        Update-MwpDashboardWidgets -Force
    }
    if (-not $result.Success) {
        Show-MwpMessage -Text $result.Message -Kind Warning -Owner $Owner
    }
    elseif ($renaming) {
        Show-MwpMessage -Text $result.Message -Owner $Owner
    }
    Update-MwpCurrentView
}
