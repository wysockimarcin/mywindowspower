function Remove-MwpDashboardWidget {
    <#
    .SYNOPSIS
        Usuwa widgety z zapisanej konfiguracji Dashboardu: wskazane identyfikatorem albo wszystkie widgety modułu.

    .DESCRIPTION
        Usuwanie z konfiguracji (D-031, D-043) — okno hosta dodatkowo usuwa widgety z Dashboardu
        i anuluje ich zadania. Stan aplikacji, bez wpisu cofnięcia. Gdy nic nie pasuje — wynik bez
        zmian i bez zapisu. Data wyniku: Removed (liczba), Ids (identyfikatory usuniętych widgetów).

    .PARAMETER ModuleId
        Id modułu, którego widgety usunąć.

    .PARAMETER Id
        Identyfikatory widgetów do usunięcia.

    .EXAMPLE
        Remove-MwpDashboardWidget -ModuleId 'Przyklad' -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium', DefaultParameterSetName = 'Module')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Module')]
        [ValidateNotNullOrEmpty()]
        [string] $ModuleId,

        [Parameter(Mandatory, ParameterSetName = 'Id')]
        [ValidateNotNullOrEmpty()]
        [string[]] $Id
    )

    $operation = 'Dashboard.RemoveWidget'
    $byModule = $PSCmdlet.ParameterSetName -eq 'Module'
    $label = if ($byModule) { "widgety modułu '{0}'" -f $ModuleId } else { 'widgety: {0}' -f ($Id -join ', ') }
    $common = @{ Operation = $operation; Target = $label; ComputerName = 'localhost' }
    $data = Read-MwpSettingsData
    $entries = Get-MwpDashboardWidgetEntry -Data $data
    $removed = @()
    $kept = @()
    foreach ($widget in @($entries.Widgets)) {
        $isMatch = if ($byModule) { $widget.moduleId -eq $ModuleId } else { $Id -contains $widget.id }
        if ($isMatch) {
            $removed += , $widget
        }
        else {
            $kept += , $widget
        }
    }
    $details = [ordered]@{ Removed = $removed.Count; Ids = @($removed | ForEach-Object { $_.id }) }
    if ($removed.Count -eq 0) {
        return New-MwpResult @common -Success $true -Message ('Brak widgetów do usunięcia ({0}).' -f $label) -Data $details
    }
    $target = Format-MwpOperationTarget -Target ('{0} w konfiguracji Dashboardu' -f $label) -ComputerName 'localhost'
    if (-not $PSCmdlet.ShouldProcess($target, ('Usunięcie widgetów: {0}' -f $removed.Count))) {
        return New-MwpResult @common -Success $true -IsPreview -Message ('Podgląd: z Dashboardu zostanie usuniętych widgetów: {0}.' -f $removed.Count) -Data $details
    }
    try {
        Write-MwpLocalSetting -Values @{ dashboardWidgets = $kept } -Data $data
        $message = 'Usunięto z konfiguracji Dashboardu widgetów: {0} ({1}).' -f $removed.Count, $label
        Write-MwpLog -Level Info -Source 'MWP.Core' -Operation $operation -Message $message -Data $details
        New-MwpResult @common -Success $true -Changed $true -Message $message -Data $details
    }
    catch {
        $message = 'Nie udało się usunąć widgetów z konfiguracji Dashboardu: {0}' -f $_.Exception.Message
        Write-MwpLog -Level Error -Source 'MWP.Core' -Operation $operation -Message $message
        New-MwpResult @common -Success $false -Message $message -ErrorMessage $_.Exception.Message
    }
}
