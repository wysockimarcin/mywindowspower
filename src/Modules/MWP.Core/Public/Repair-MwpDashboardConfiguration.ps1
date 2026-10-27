function Repair-MwpDashboardConfiguration {
    <#
    .SYNOPSIS
        Sprawdza widgety zapisanej konfiguracji Dashboardu z modułami i usuwa widgety modułów, których już nie ma.

    .DESCRIPTION
        Wywoływana przy odtwarzaniu konfiguracji (start Dashboardu, D-031, D-043). Widget modułu,
        którego nie ma (odinstalowany, usunięty folder) albo który nie deklaruje już tego typu widgetu,
        jest pomijany z ostrzeżeniem w logu i usuwany z zapisu. Widget modułu obecnego, ale z błędnym
        kontraktem, zostaje w zapisie (moduł może wrócić po naprawie), lecz nie jest odtwarzany
        (lista Unavailable). Bez -WhatIf zapisuje oczyszczoną listę tylko wtedy, gdy coś usunięto.
        Data wyniku: Widgets (widgety do odtworzenia: Widget — wpis konfiguracji, Definition —
        MWP.WidgetDefinition), Removed i Unavailable (Widget, Reason), Configuration
        (MWP.DashboardConfiguration przed naprawą).

    .PARAMETER Definition
        Definicje modułów (Get-MwpModuleDefinition); domyślnie odczytywane z dysku.

    .EXAMPLE
        (Repair-MwpDashboardConfiguration -WhatIf).Data.Removed
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([pscustomobject])]
    param(
        [AllowEmptyCollection()]
        [object[]] $Definition
    )

    $operation = 'Dashboard.Restore'
    $common = @{ Operation = $operation; Target = 'Dashboard'; ComputerName = 'localhost' }
    if (-not $PSBoundParameters.ContainsKey('Definition')) {
        $Definition = @(Get-MwpModuleDefinition)
    }
    $configuration = Get-MwpDashboardConfiguration
    $catalog = @(Get-MwpWidgetDefinition -Definition $Definition)

    $restore = New-Object -TypeName System.Collections.Generic.List[object]
    $removed = New-Object -TypeName System.Collections.Generic.List[object]
    $unavailable = New-Object -TypeName System.Collections.Generic.List[object]
    foreach ($widget in @($configuration.Widgets)) {
        $module = @($Definition | Where-Object { $null -ne $_ -and $_.Id -eq $widget.moduleId }) | Select-Object -First 1
        $widgetDefinition = @($catalog | Where-Object { $_.ModuleId -eq $widget.moduleId -and $_.WidgetId -eq $widget.widgetId }) | Select-Object -First 1
        if ($null -eq $module) {
            $removed.Add([pscustomobject]@{ Widget = $widget; Reason = ("moduł '{0}' nie jest zainstalowany" -f $widget.moduleId) })
        }
        elseif (-not $module.IsValid) {
            $unavailable.Add([pscustomobject]@{ Widget = $widget; Reason = ("moduł '{0}' ma niepoprawny kontrakt: {1}" -f $module.ModuleName, ($module.Errors -join ' ')) })
        }
        elseif ($null -eq $widgetDefinition) {
            $removed.Add([pscustomobject]@{ Widget = $widget; Reason = ("moduł '{0}' nie ma widgetu '{1}'" -f $module.ModuleName, $widget.widgetId) })
        }
        else {
            $restore.Add([pscustomobject]@{ Widget = $widget; Definition = $widgetDefinition })
        }
    }

    $details = [ordered]@{
        Widgets       = $restore.ToArray()
        Removed       = $removed.ToArray()
        Unavailable   = $unavailable.ToArray()
        Configuration = $configuration
    }
    foreach ($item in $unavailable) {
        Write-MwpLog -Level Warning -Source 'MWP.Core' -Operation $operation -Message ("Widget '{0}' nie zostanie odtworzony: {1}." -f $item.Widget.id, $item.Reason)
    }
    if ($removed.Count -eq 0) {
        return New-MwpResult @common -Success $true -Message ('Odtworzono konfigurację Dashboardu (widgety: {0}).' -f $restore.Count) -Data $details
    }

    $reasons = @($removed | ForEach-Object { '{0} ({1})' -f $_.Widget.id, $_.Reason }) -join '; '
    $target = Format-MwpOperationTarget -Target 'konfiguracja Dashboardu' -ComputerName 'localhost'
    if (-not $PSCmdlet.ShouldProcess($target, ('Usunięcie widgetów modułów, których nie ma: {0}' -f $reasons))) {
        return New-MwpResult @common -Success $true -IsPreview -Message ('Podgląd: z konfiguracji Dashboardu zostaną usunięte widgety: {0}.' -f $reasons) -Data $details
    }
    $removedIds = @($removed | ForEach-Object { $_.Widget.id })
    $kept = @($configuration.Widgets | Where-Object { $removedIds -notcontains $_.id })
    try {
        Write-MwpLocalSetting -Values @{ dashboardWidgets = $kept }
        $message = 'Pominięto i usunięto z konfiguracji Dashboardu widgety modułów, których nie ma: {0}.' -f $reasons
        Write-MwpLog -Level Warning -Source 'MWP.Core' -Operation $operation -Message $message -Data @{ Ids = $removedIds }
        New-MwpResult @common -Success $true -Changed $true -Message $message -Data $details
    }
    catch {
        $message = 'Pominięto widgety modułów, których nie ma ({0}), ale nie udało się zapisać konfiguracji: {1}' -f $reasons, $_.Exception.Message
        Write-MwpLog -Level Error -Source 'MWP.Core' -Operation $operation -Message $message
        New-MwpResult @common -Success $false -Message $message -ErrorMessage $_.Exception.Message -Data $details
    }
}
