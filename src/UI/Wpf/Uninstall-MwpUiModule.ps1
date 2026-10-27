function Uninstall-MwpUiModule {
    <#
    .SYNOPSIS
        Odinstalowanie modułu z paczki: podgląd, potwierdzenie z wpisaniem nazwy modułu, zamknięcie instancji, usunięcie w tle.

    .DESCRIPTION
        Klasa Destrukcyjna (D-027, D-031). Instancje modułu i jego widgety Dashboardu są zamykane
        w oknie (rejestr instancji należy do runspace'u okna; widget anuluje swoje zadanie), potem
        Uninstall-MwpModulePackage usuwa folder, sekcję konfiguracji, widgety z zapisanej konfiguracji
        Dashboardu i wpis w rejestrze (w tle), a okno usuwa moduł z sesji i odświeża katalog modułów.
        Moduły bazowe i wbudowane nie mają tej akcji (CanUninstall).
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory)]
        [object] $Row,

        [AllowNull()]
        [object] $Owner
    )

    $ui = $script:MwpUi
    if (-not $Row.CanUninstall) {
        return
    }
    $preview = Uninstall-MwpModulePackage -Id $Row.Id -WhatIf
    if (-not $preview.IsPreview) {
        Show-MwpMessage -Text $preview.Message -Kind Warning -Owner $Owner
        return
    }
    $open = @($ui.Instances.Values | Where-Object { $_.Instance.ModuleId -eq $Row.Id })
    $widgets = @()
    if ($null -ne $ui.Dashboard) {
        $widgets = @($ui.Dashboard.Widgets | Where-Object { $_.Config['moduleId'] -eq $Row.Id })
    }
    $lines = @(ConvertTo-MwpPreviewLine -Result $preview) + @(
        'Folder do usunięcia: {0}' -f $Row.Path
        'Otwarte instancje do zamknięcia: {0}' -f $open.Count
        'Widgety Dashboardu do usunięcia: {0}' -f $widgets.Count
        'Zostają: logi operacji i rejestr cofnięć (audyt zmian w systemie).'
    )
    $confirmed = Show-MwpConfirmDialog -Header 'Odinstalowanie modułu' -Target ("Moduł '{0}' ({1}, wersja {2})" -f $Row.Name, $Row.ModuleName, $Row.Version) `
        -PreviewLine $lines -Class Destructive -RequireText $Row.ModuleName -ConfirmText 'Odinstaluj' -Owner $Owner `
        -Warning 'Odinstalowania nie cofa rejestr cofnięć; moduł można zainstalować ponownie z paczki.'
    if (-not $confirmed -or -not $PSCmdlet.ShouldProcess($Row.ModuleName, 'Odinstalowanie modułu')) {
        return
    }
    foreach ($entry in $open) {
        Close-MwpUiInstance -Id $entry.Id
    }
    foreach ($widget in $widgets) {
        Remove-MwpWidgetRuntime -Widget $widget -Confirm:$false
        $null = $ui.Dashboard.Widgets.Remove($widget)
    }
    if ($widgets.Count -gt 0) {
        Update-MwpDashboardWidgets -Force
    }
    $null = Start-MwpUiTask -Registry $ui.Tasks -Pool $ui.Pool -Name ('Odinstalowanie: {0}' -f $Row.ModuleName) -ArgumentList @(, $Row.Id) -State @{ Owner = $Owner; ModuleName = $Row.ModuleName } -ScriptBlock {
        param($Progress, $Id)
        $Progress.Message = 'usuwanie folderu i konfiguracji modułu'
        Uninstall-MwpModulePackage -Id $Id -Confirm:$false
    } -OnCompleted {
        param($Task)
        $result = @($Task.Output | Where-Object { $_.PSObject.TypeNames -contains 'MWP.Result' }) | Select-Object -Last 1
        if ($null -ne $result -and $result.Success) {
            Get-Module -Name $Task.State.ModuleName | Remove-Module -Force
        }
        $text = if ($null -eq $result) { 'Odinstalowanie nie powiodło się: {0}' -f $Task.Error } else { $result.Message }
        Update-MwpModuleCatalog
        if ($null -ne $script:MwpUi.Dashboard) {
            $script:MwpUi.Dashboard.Catalog = @(Get-MwpWidgetDefinition -Definition $script:MwpUi.Definitions)
        }
        Show-MwpMessage -Text $text -Kind $(if ($null -ne $result -and $result.Success) { 'Info' } else { 'Warning' }) -Owner $Task.State.Owner
    }
}
