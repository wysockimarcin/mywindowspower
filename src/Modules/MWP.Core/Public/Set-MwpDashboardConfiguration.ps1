function Set-MwpDashboardConfiguration {
    <#
    .SYNOPSIS
        Zapisuje konfigurację Dashboardu (lista widgetów i/lub odświeżanie automatyczne) w ustawieniach lokalnych.

    .DESCRIPTION
        Stan aplikacji, nie zmiana systemu (D-043): zapis atomowy (Write-MwpLocalSetting), log
        Dashboard.Save, bez wpisu w rejestrze cofnięć (układ Dashboardu zmienia się często, a cofnięcie
        to ponowna edycja). Każdy wpis widgetu jest sprawdzany (ConvertTo-MwpDashboardWidget);
        niepoprawny wpis albo powtórzony identyfikator — wynik z błędem i brak zapisu.
        Kolejność listy = kolejność widgetów na Dashboardzie.

    .PARAMETER Widget
        Pełna lista widgetów (słowniki albo obiekty z polami jak w Get-MwpDashboardConfiguration).

    .PARAMETER AutoRefresh
        Odświeżanie automatyczne widgetów (globalny przełącznik Dashboardu).

    .EXAMPLE
        $c = Get-MwpDashboardConfiguration; Set-MwpDashboardConfiguration -Widget $c.Widgets -AutoRefresh $false -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([pscustomobject])]
    param(
        [AllowEmptyCollection()]
        [object[]] $Widget,

        [Nullable[bool]] $AutoRefresh
    )

    $operation = 'Dashboard.Save'
    $common = @{ Operation = $operation; Target = 'Dashboard'; ComputerName = 'localhost' }
    $values = [ordered]@{}
    if ($PSBoundParameters.ContainsKey('Widget')) {
        $list = New-Object -TypeName System.Collections.Generic.List[object]
        $ids = @{}
        try {
            foreach ($entry in @($Widget | Where-Object { $null -ne $_ })) {
                $normalized = ConvertTo-MwpDashboardWidget -InputObject $entry
                if ($ids.ContainsKey($normalized.id)) {
                    throw ("Powtórzony identyfikator widgetu '{0}'." -f $normalized.id)
                }
                $ids[$normalized.id] = $true
                $list.Add($normalized)
            }
        }
        catch {
            return New-MwpResult @common -Success $false -Message ("Niepoprawna konfiguracja Dashboardu: {0}" -f $_.Exception.Message)
        }
        $values['dashboardWidgets'] = $list.ToArray()
    }
    if ($null -ne $AutoRefresh) {
        $values['dashboardAutoRefresh'] = [bool]$AutoRefresh
    }
    if ($values.Count -eq 0) {
        return New-MwpResult @common -Success $true -Message 'Brak zmian w konfiguracji Dashboardu.'
    }

    $parts = @()
    if ($values.Contains('dashboardWidgets')) {
        $parts += 'widgety: {0}' -f @($values['dashboardWidgets']).Count
    }
    if ($values.Contains('dashboardAutoRefresh')) {
        $parts += 'odświeżanie automatyczne: {0}' -f $(if ($values['dashboardAutoRefresh']) { 'włączone' } else { 'wyłączone' })
    }
    $description = $parts -join '; '
    $target = Format-MwpOperationTarget -Target 'konfiguracja Dashboardu' -ComputerName 'localhost'
    if (-not $PSCmdlet.ShouldProcess($target, ('Zapis ({0})' -f $description))) {
        return New-MwpResult @common -Success $true -IsPreview -After $values -Message ("Podgląd: zapis konfiguracji Dashboardu ({0})." -f $description)
    }
    try {
        Write-MwpLocalSetting -Values $values
        $message = 'Zapisano konfigurację Dashboardu ({0}).' -f $description
        Write-MwpLog -Level Info -Source 'MWP.Core' -Operation $operation -Message $message
        New-MwpResult @common -Success $true -Changed $true -After $values -Message $message
    }
    catch {
        $message = 'Nie udało się zapisać konfiguracji Dashboardu: {0}' -f $_.Exception.Message
        Write-MwpLog -Level Error -Source 'MWP.Core' -Operation $operation -Message $message
        New-MwpResult @common -Success $false -Message $message -ErrorMessage $_.Exception.Message
    }
}
