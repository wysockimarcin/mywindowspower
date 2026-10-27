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
        i SupportsRemote (moduł deklaruje RemoteTarget). Pomija moduły z niepoprawnym kontraktem.

    .PARAMETER ModuleId
        Tylko widgety tego modułu (Id albo nazwa folderu).

    .PARAMETER Definition
        Definicje modułów (Get-MwpModuleDefinition); domyślnie odczytywane z dysku.

    .EXAMPLE
        Get-MwpWidgetDefinition | Select-Object Key, Name
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [ValidateNotNullOrEmpty()]
        [string] $ModuleId,

        [AllowEmptyCollection()]
        [object[]] $Definition
    )

    if (-not $PSBoundParameters.ContainsKey('Definition')) {
        $Definition = @(Get-MwpModuleDefinition)
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
            [pscustomobject]@{
                PSTypeName            = 'MWP.WidgetDefinition'
                Key                   = '{0}.{1}' -f $module.Id, $widget['Id']
                ModuleId              = $module.Id
                ModuleName            = $module.ModuleName
                ModuleTitle           = $module.Name
                WidgetId              = [string]$widget['Id']
                Name                  = [string]$widget['Name']
                Description           = [string]$widget['Description']
                DataCommand           = [string]$widget['DataCommand']
                ViewCommand           = [string]$widget['ViewCommand']
                ExportCommand         = $(if ([string]::IsNullOrWhiteSpace([string]$widget['ExportCommand'])) { $null } else { [string]$widget['ExportCommand'] })
                DefaultRefreshSeconds = $(if ($widget.Contains('DefaultRefreshSeconds')) { [int]$widget['DefaultRefreshSeconds'] } else { 60 })
                Parameters            = $parameters
                SupportsRemote        = @($module.Capabilities) -contains 'RemoteTarget'
            }
        }
    }
}
