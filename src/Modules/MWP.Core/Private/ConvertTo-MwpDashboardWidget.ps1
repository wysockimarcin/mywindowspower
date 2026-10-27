function ConvertTo-MwpDashboardWidget {
    <#
    .SYNOPSIS
        Sprawdza i ujednolica wpis konfiguracji widgetu Dashboardu (klucz dashboardWidgets, D-043).

    .DESCRIPTION
        Przyjmuje słownik albo obiekt (z pliku JSON lub z GUI) i zwraca słownik uporządkowany:
        id, moduleId, widgetId, computerName, title, refreshSeconds, size, parameters. Brak wymaganych
        pól albo niedozwolona wartość kończy się wyjątkiem z komunikatem po polsku (wywołujący pomija
        taki wpis z ostrzeżeniem). Domyślnie: computerName = localhost, refreshSeconds = 60,
        size = Normal, parameters = pusta tabela. Nazwy komputera nie sprawdza z rejestrem komputerów
        (komputer usunięty z rejestru daje błąd tylko w swoim widgecie).
    #>
    [CmdletBinding()]
    [OutputType([Collections.Specialized.OrderedDictionary])]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object] $InputObject
    )

    if ($null -eq $InputObject) {
        throw 'Pusty wpis widgetu.'
    }
    $source = $InputObject
    if ($source -isnot [Collections.IDictionary]) {
        $source = ConvertTo-MwpHashtable -InputObject $source
    }
    if ($source -isnot [Collections.IDictionary]) {
        throw 'Wpis widgetu nie jest obiektem.'
    }
    $vocabulary = Get-MwpContractVocabulary
    $value = {
        param([string] $Name, $Default)
        if ($source.Contains($Name) -and $null -ne $source[$Name] -and [string]$source[$Name] -ne '') { $source[$Name] } else { $Default }
    }

    $id = [string](& $value 'id' '')
    if ($id -notmatch '^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$') {
        throw ("Niepoprawny identyfikator widgetu '{0}'." -f $id)
    }
    $moduleId = [string](& $value 'moduleId' '')
    $widgetId = [string](& $value 'widgetId' '')
    if ($moduleId -notmatch '^[A-Za-z][A-Za-z0-9]*$' -or $widgetId -notmatch '^[A-Za-z][A-Za-z0-9]*$') {
        throw ("Widget '{0}' nie ma poprawnych pól moduleId i widgetId." -f $id)
    }
    $computerName = [string](& $value 'computerName' 'localhost')
    $refresh = & $value 'refreshSeconds' 60
    $refreshNumber = 0
    if (-not [int]::TryParse([string]$refresh, [ref]$refreshNumber) -or $vocabulary.WidgetRefreshSeconds -notcontains $refreshNumber) {
        throw ("Widget '{0}': niedozwolona częstotliwość odświeżania '{1}' (dozwolone: {2})." -f $id, $refresh, ($vocabulary.WidgetRefreshSeconds -join ', '))
    }
    $size = [string](& $value 'size' 'Normal')
    if ($vocabulary.WidgetSizes -notcontains $size) {
        throw ("Widget '{0}': niedozwolony rozmiar '{1}' (dozwolone: {2})." -f $id, $size, ($vocabulary.WidgetSizes -join ', '))
    }
    $parameters = [ordered]@{}
    $rawParameters = & $value 'parameters' $null
    if ($null -ne $rawParameters) {
        if ($rawParameters -isnot [Collections.IDictionary]) {
            $rawParameters = ConvertTo-MwpHashtable -InputObject $rawParameters
        }
        if ($rawParameters -isnot [Collections.IDictionary]) {
            throw ("Widget '{0}': pole parameters musi być obiektem." -f $id)
        }
        foreach ($key in $rawParameters.Keys) {
            $parameters[[string]$key] = $rawParameters[$key]
        }
    }

    [ordered]@{
        id             = $id
        moduleId       = $moduleId
        widgetId       = $widgetId
        computerName   = $computerName
        title          = [string](& $value 'title' '')
        refreshSeconds = $refreshNumber
        size           = $size
        parameters     = $parameters
    }
}
