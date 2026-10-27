function Get-MwpWidgetParameterSet {
    <#
    .SYNOPSIS
        Zwraca parametry widgetu: wartości domyślne ze schematu widgetu nadpisane wartościami z konfiguracji.

    .PARAMETER Configuration
        Wpis konfiguracji widgetu (klucz parameters).

    .PARAMETER Definition
        Definicja widgetu (Parameters — schemat z Type i Default).
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [Collections.IDictionary] $Configuration,

        [Parameter(Mandatory)]
        [object] $Definition
    )

    $parameters = @{}
    if ($Definition.Parameters -is [Collections.IDictionary]) {
        foreach ($key in @($Definition.Parameters.Keys)) {
            $parameters[[string]$key] = $Definition.Parameters[$key]['Default']
        }
    }
    if ($Configuration['parameters'] -is [Collections.IDictionary]) {
        foreach ($key in @($Configuration['parameters'].Keys)) {
            $parameters[[string]$key] = $Configuration['parameters'][$key]
        }
    }
    $parameters
}
