function ConvertTo-MwpWidgetConfiguration {
    <#
    .SYNOPSIS
        Zamienia widgety okna na listę wpisów konfiguracji do zapisu (Set-MwpDashboardConfiguration).

    .DESCRIPTION
        Kolejność listy = kolejność widgetów na Dashboardzie. Widgety usunięte są pomijane. Wpis
        zawiera tylko konfigurację (bez stanu, danych i instancji), więc zapis nie zależy od wyniku
        odświeżania.

    .PARAMETER Widget
        Widgety Dashboardu (tabele z New-MwpWidgetRuntime).
    #>
    [CmdletBinding()]
    [OutputType([Collections.Specialized.OrderedDictionary])]
    param(
        [AllowEmptyCollection()]
        [object[]] $Widget = @()
    )

    foreach ($item in @($Widget | Where-Object { $null -ne $_ -and -not $_.Removed })) {
        $config = $item.Config
        $parameters = [ordered]@{}
        if ($config['parameters'] -is [Collections.IDictionary]) {
            foreach ($key in @($config['parameters'].Keys)) {
                $parameters[[string]$key] = $config['parameters'][$key]
            }
        }
        [ordered]@{
            id             = [string]$config['id']
            moduleId       = [string]$config['moduleId']
            widgetId       = [string]$config['widgetId']
            computerName   = [string]$config['computerName']
            title          = [string]$config['title']
            refreshSeconds = [int]$config['refreshSeconds']
            size           = [string]$config['size']
            parameters     = $parameters
        }
    }
}
