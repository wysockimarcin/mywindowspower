function Get-MwpWidgetDefinition {
    <#
    .SYNOPSIS
        Zwraca katalog widgetów Dashboardu zadeklarowanych przez moduły (pole Widgets kontraktu, D-043).

    .DESCRIPTION
        Widget to kontrakt prezentacji danych modułu, nie miniaturowe okno. Każda definicja
        (MWP.WidgetDefinition) ma: Key (<Id modułu>.<Id widgetu>), ModuleId, ModuleName, ModuleTitle,
        WidgetId, Name, Description, DataCommand (funkcja danych: -Context -AsOperation
        -WidgetParameters → MWP.Operation), ViewCommand (funkcja widoku: -Data -WidgetParameters →
        MWP.WidgetView), ExportCommand (opcjonalnie: -Data -Path [-Format] → MWP.Result),
        DefaultRefreshSeconds, Parameters (schemat parametrów: Type, Default, opcjonalnie Values, Label)
        i SupportsRemote (moduł deklaruje RemoteTarget, a widget nie ma LocalOnly). Pomija moduły
        z niepoprawnym kontraktem.

        Konfiguracja widgetów modułu (D-053): Enabled (z manifestu, domyślnie $true), LocalOnly,
        Visible (ustawienie użytkownika modules.<Id>.widgets.<Id>.visible, a bez niego Enabled) i
        DefaultParameters (wartości początkowe nowego widgetu: Default ze schematu nadpisane poprawnymi
        defaultParameters użytkownika; niepoprawne — pominięte z ostrzeżeniem w logu). Bez -Addable
        zwraca katalog pełny (odtwarzanie Dashboardu — ukryty typ nadal się odtwarza), z -Addable —
        katalog do dodawania (tylko Visible).

    .PARAMETER ModuleId
        Tylko widgety tego modułu (Id albo nazwa folderu).

    .PARAMETER Definition
        Definicje modułów (Get-MwpModuleDefinition); domyślnie odczytywane z dysku.

    .PARAMETER WidgetSetting
        Ustawienia użytkownika (Get-MwpWidgetSetting); domyślnie odczytywane z ustawień lokalnych.

    .PARAMETER Addable
        Tylko typy widoczne na liście „Dodaj widżet”.

    .EXAMPLE
        Get-MwpWidgetDefinition | Select-Object Key, Name
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [ValidateNotNullOrEmpty()]
        [string] $ModuleId,

        [AllowEmptyCollection()]
        [object[]] $Definition,

        [AllowEmptyCollection()]
        [object[]] $WidgetSetting,

        [switch] $Addable
    )

    if (-not $PSBoundParameters.ContainsKey('Definition')) {
        $Definition = @(Get-MwpModuleDefinition)
    }
    if (-not $PSBoundParameters.ContainsKey('WidgetSetting')) {
        try {
            $WidgetSetting = @(Get-MwpWidgetSetting)
        }
        catch {
            $WidgetSetting = @()
            Write-MwpLog -Level Warning -Source 'MWP.Core' -Operation 'Widgets.Catalog' -Message ('Nie udało się odczytać ustawień widżetów: {0}' -f $_.Exception.Message)
        }
    }
    foreach ($module in @($Definition | Where-Object { $null -ne $_ -and $_.IsValid })) {
        if ($PSBoundParameters.ContainsKey('ModuleId') -and $module.Id -ne $ModuleId -and $module.ModuleName -ne $ModuleId) {
            continue
        }
        if ($null -eq $module.PSObject.Properties['Widgets']) {
            continue
        }
        foreach ($widget in @($module.Widgets | Where-Object { $_ -is [Collections.IDictionary] })) {
            $parameters = [ordered]@{}
            if ($widget['Parameters'] -is [Collections.IDictionary]) {
                foreach ($key in @($widget['Parameters'].Keys | Sort-Object)) {
                    $parameters[$key] = $widget['Parameters'][$key]
                }
            }
            $widgetId = [string]$widget['Id']
            $enabled = -not ($widget.Contains('Enabled') -and $widget['Enabled'] -is [bool] -and -not $widget['Enabled'])
            $localOnly = $widget.Contains('LocalOnly') -and $widget['LocalOnly'] -is [bool] -and $widget['LocalOnly']
            $setting = @($WidgetSetting | Where-Object { $null -ne $_ -and $_.ModuleId -eq $module.Id -and $_.WidgetId -eq $widgetId }) | Select-Object -First 1
            $visible = $(if ($null -ne $setting -and $null -ne $setting.Visible) { [bool]$setting.Visible } else { $enabled })
            if ($Addable -and -not $visible) {
                continue
            }
            $defaults = [ordered]@{}
            foreach ($key in @($parameters.Keys)) {
                $defaults[$key] = $(if ($parameters[$key] -is [Collections.IDictionary]) { $parameters[$key]['Default'] } else { $null })
            }
            if ($null -ne $setting -and $setting.DefaultParameters -is [Collections.IDictionary]) {
                foreach ($key in @($setting.DefaultParameters.Keys)) {
                    $problem = $null
                    if ($parameters[[string]$key] -isnot [Collections.IDictionary]) {
                        $problem = 'parametr nie istnieje w schemacie widgetu'
                    }
                    else {
                        $check = ConvertTo-MwpWidgetParameterValue -Schema $parameters[[string]$key] -Value $setting.DefaultParameters[$key]
                        if ($check.Valid) {
                            $defaults[[string]$key] = $check.Value
                        }
                        else {
                            $problem = $check.Problem
                        }
                    }
                    if ($problem) {
                        Write-MwpLog -Level Warning -Source 'MWP.Core' -Operation 'Widgets.Catalog' -Message ("Pominięto domyślny parametr '{0}' widgetu '{1}.{2}' z ustawień użytkownika ({3}); obowiązuje wartość z manifestu." -f $key, $module.Id, $widgetId, $problem)
                    }
                }
            }
            [pscustomobject]@{
                PSTypeName            = 'MWP.WidgetDefinition'
                Key                   = '{0}.{1}' -f $module.Id, $widgetId
                ModuleId              = $module.Id
                ModuleName            = $module.ModuleName
                ModuleTitle           = $module.Name
                WidgetId              = $widgetId
                Name                  = [string]$widget['Name']
                Description           = [string]$widget['Description']
                DataCommand           = [string]$widget['DataCommand']
                ViewCommand           = [string]$widget['ViewCommand']
                ExportCommand         = $(if ([string]::IsNullOrWhiteSpace([string]$widget['ExportCommand'])) { $null } else { [string]$widget['ExportCommand'] })
                DefaultRefreshSeconds = $(if ($widget.Contains('DefaultRefreshSeconds')) { [int]$widget['DefaultRefreshSeconds'] } else { 60 })
                Parameters            = $parameters
                SupportsRemote        = @($module.Capabilities) -contains 'RemoteTarget' -and -not $localOnly
                LocalOnly             = [bool]$localOnly
                Enabled               = [bool]$enabled
                Visible               = [bool]$visible
                DefaultParameters     = $defaults
            }
        }
    }
}
