function Set-MwpWidgetSetting {
    <#
    .SYNOPSIS
        Zapisuje ustawienia użytkownika dla typów widgetów modułu: widoczność na liście „Dodaj widżet” i domyślne parametry nowych widgetów.

    .DESCRIPTION
        Stan aplikacji, nie zmiana systemu (D-053, jak Set-MwpDashboardConfiguration w D-043): zapis
        atomowy w settings.local.json (modules.<Id modułu>.widgets.<Id widgetu>), log Widgets.Settings,
        bez wpisu w rejestrze cofnięć (cofnięcie to ponowna zmiana albo -Reset). Ukrycie typu
        (-Visible $false) usuwa go tylko z listy „Dodaj widżet”; widgety tego typu już dodane na
        Dashboard zostają i działają. -DefaultParameters dotyczy nowych widgetów; istniejące mają
        własne parametry. Parametry są sprawdzane ze schematem widgetu (nieznana nazwa, zły typ albo
        wartość spoza Values — wynik z błędem i brak zapisu). Pozostałe ustawienia modułu pod kluczem
        modules.<Id> zostają bez zmian.

    .PARAMETER ModuleId
        Id modułu (pole Id kontraktu).

    .PARAMETER WidgetId
        Id jednego albo kilku typów widgetów modułu (kilka — np. „Ukryj wszystkie widżety modułu”).

    .PARAMETER Visible
        Widoczność typu na liście „Dodaj widżet”.

    .PARAMETER DefaultParameters
        Domyślne parametry nowych widgetów (tylko dla jednego typu); pełny zestaw zastępuje poprzedni.

    .PARAMETER Reset
        Usuwa ustawienia użytkownika wskazanych typów (powrót do wartości z manifestu).

    .PARAMETER Definition
        Definicje modułów (Get-MwpModuleDefinition); domyślnie odczytywane z dysku.

    .EXAMPLE
        Set-MwpWidgetSetting -ModuleId Dashboard -WidgetId SystemInfo -Visible $false -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidatePattern('^[A-Za-z][A-Za-z0-9]*$')]
        [string] $ModuleId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^[A-Za-z][A-Za-z0-9]*$')]
        [string[]] $WidgetId,

        [Nullable[bool]] $Visible,

        [Collections.IDictionary] $DefaultParameters,

        [switch] $Reset,

        [AllowEmptyCollection()]
        [object[]] $Definition
    )

    $operation = 'Widgets.Settings'
    $common = @{ Operation = $operation; Target = ('widżety modułu {0}' -f $ModuleId); ComputerName = 'localhost' }
    $fail = {
        param([string] $Message)
        New-MwpResult @common -Success $false -Message $Message
    }
    $WidgetId = @($WidgetId | Select-Object -Unique)
    if ($Reset -and ($null -ne $Visible -or $PSBoundParameters.ContainsKey('DefaultParameters'))) {
        return & $fail '-Reset nie łączy się z -Visible ani -DefaultParameters.'
    }
    if (-not $Reset -and $null -eq $Visible -and -not $PSBoundParameters.ContainsKey('DefaultParameters')) {
        return & $fail 'Podaj -Visible, -DefaultParameters albo -Reset.'
    }
    if ($PSBoundParameters.ContainsKey('DefaultParameters') -and $WidgetId.Count -ne 1) {
        return & $fail '-DefaultParameters dotyczy jednego typu widgetu.'
    }
    if (-not $PSBoundParameters.ContainsKey('Definition')) {
        $Definition = @(Get-MwpModuleDefinition)
    }
    $catalog = @(Get-MwpWidgetDefinition -Definition $Definition -ModuleId $ModuleId -WidgetSetting @())
    foreach ($id in $WidgetId) {
        if (@($catalog | Where-Object { $_.ModuleId -eq $ModuleId -and $_.WidgetId -eq $id }).Count -eq 0) {
            return & $fail ("Moduł '{0}' nie ma widgetu '{1}'." -f $ModuleId, $id)
        }
    }

    $normalized = $null
    if ($PSBoundParameters.ContainsKey('DefaultParameters')) {
        $schema = (@($catalog | Where-Object { $_.WidgetId -eq $WidgetId[0] }) | Select-Object -First 1).Parameters
        $normalized = [ordered]@{}
        $problems = @()
        foreach ($key in @($DefaultParameters.Keys | Sort-Object)) {
            if (-not $schema.Contains([string]$key)) {
                $problems += "nieznany parametr '{0}'" -f $key
                continue
            }
            $check = ConvertTo-MwpWidgetParameterValue -Schema $schema[[string]$key] -Value $DefaultParameters[$key]
            if ($check.Valid) {
                $normalized[[string]$key] = $check.Value
            }
            else {
                $problems += "parametr '{0}': {1}" -f $key, $check.Problem
            }
        }
        if ($problems.Count -gt 0) {
            return & $fail ("Niepoprawne domyślne parametry widgetu '{0}.{1}': {2}." -f $ModuleId, $WidgetId[0], ($problems -join '; '))
        }
    }

    $data = Read-MwpSettingsData
    $modules = [ordered]@{}
    if ($data.Settings['modules'] -is [Collections.IDictionary]) {
        foreach ($key in @($data.Settings['modules'].Keys)) {
            $modules[[string]$key] = $data.Settings['modules'][$key]
        }
    }
    $module = [ordered]@{}
    if ($modules[$ModuleId] -is [Collections.IDictionary]) {
        foreach ($key in @($modules[$ModuleId].Keys)) {
            $module[[string]$key] = $modules[$ModuleId][$key]
        }
    }
    $widgets = [ordered]@{}
    if ($module['widgets'] -is [Collections.IDictionary]) {
        foreach ($key in @($module['widgets'].Keys)) {
            $widgets[[string]$key] = $module['widgets'][$key]
        }
    }
    foreach ($id in $WidgetId) {
        if ($Reset) {
            $widgets.Remove($id)
            continue
        }
        $entry = [ordered]@{}
        if ($widgets[$id] -is [Collections.IDictionary]) {
            foreach ($key in @($widgets[$id].Keys)) {
                $entry[[string]$key] = $widgets[$id][$key]
            }
        }
        if ($null -ne $Visible) {
            $entry['visible'] = [bool]$Visible
        }
        if ($null -ne $normalized) {
            $entry['defaultParameters'] = $normalized
        }
        $widgets[$id] = $entry
    }
    if ($widgets.Count -gt 0) {
        $module['widgets'] = $widgets
    }
    else {
        $module.Remove('widgets')
    }
    if ($module.Count -gt 0) {
        $modules[$ModuleId] = $module
    }
    else {
        $modules.Remove($ModuleId)
    }

    $parts = @()
    if ($Reset) {
        $parts += 'przywrócenie wartości z manifestu'
    }
    if ($null -ne $Visible) {
        $parts += $(if ($Visible) { 'widoczne na liście „Dodaj widżet”' } else { 'ukryte na liście „Dodaj widżet”' })
    }
    if ($null -ne $normalized) {
        $parts += 'domyślne parametry: {0}' -f $(if ($normalized.Count -gt 0) { @($normalized.Keys | ForEach-Object { '{0}={1}' -f $_, (@($normalized[$_]) -join ',') }) -join '; ' } else { '(z manifestu)' })
    }
    $description = '{0} — {1}' -f (@($WidgetId | ForEach-Object { '{0}.{1}' -f $ModuleId, $_ }) -join ', '), ($parts -join '; ')
    $target = Format-MwpOperationTarget -Target 'ustawienia widżetów' -ComputerName 'localhost'
    if (-not $PSCmdlet.ShouldProcess($target, ('Zapis ({0})' -f $description))) {
        return New-MwpResult @common -Success $true -IsPreview -After $module -Message ('Podgląd: zapis ustawień widżetów ({0}).' -f $description)
    }
    try {
        Write-MwpLocalSetting -Values @{ modules = $modules } -Data $data
        $message = 'Zapisano ustawienia widżetów ({0}).' -f $description
        Write-MwpLog -Level Info -Source 'MWP.Core' -Operation $operation -Message $message
        New-MwpResult @common -Success $true -Changed $true -After $module -Message $message
    }
    catch {
        $message = 'Nie udało się zapisać ustawień widżetów: {0}' -f $_.Exception.Message
        Write-MwpLog -Level Error -Source 'MWP.Core' -Operation $operation -Message $message
        New-MwpResult @common -Success $false -Message $message -ErrorMessage $_.Exception.Message
    }
}
