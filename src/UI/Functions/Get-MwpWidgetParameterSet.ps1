function Get-MwpWidgetParameterSet {
    <#
    .SYNOPSIS
        Zwraca parametry widgetu: wartości domyślne ze schematu widgetu nadpisane wartościami z konfiguracji.

    .DESCRIPTION
        Parametr, którego nie ma w zapisanej konfiguracji, dostaje PreviousDefault ze schematu (jeśli jest),
        a w przeciwnym razie Default. PreviousDefault (D-053) to wartość dla widgetów zapisanych, zanim
        parametr istniał: okno widgetu zapisuje wszystkie parametry schematu, więc brak klucza oznacza
        starszy zapis — dzięki temu nowy parametr z minimalnym Default nie zmienia wyglądu istniejących
        widgetów.

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
            $schema = $Definition.Parameters[$key]
            $parameters[[string]$key] = $(if ($schema.Contains('PreviousDefault')) { $schema['PreviousDefault'] } else { $schema['Default'] })
        }
    }
    if ($Configuration['parameters'] -is [Collections.IDictionary]) {
        foreach ($key in @($Configuration['parameters'].Keys)) {
            $parameters[[string]$key] = $Configuration['parameters'][$key]
        }
    }
    $parameters
}
