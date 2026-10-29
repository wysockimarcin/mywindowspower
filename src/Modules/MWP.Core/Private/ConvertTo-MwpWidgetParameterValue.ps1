function ConvertTo-MwpWidgetParameterValue {
    <#
    .SYNOPSIS
        Sprawdza wartość parametru widgetu ze schematem (Type, Values) i zwraca ją w postaci zgodnej z typem.

    .DESCRIPTION
        Wspólna walidacja domyślnych parametrów widgetów ustawianych przez użytkownika (D-053):
        Bool — wartość logiczna (także tekst true/false), Int — liczba całkowita, String — tekst
        (z listy Values, jeśli ją podano), StringArray — lista tekstów (każdy z listy Values, jeśli ją
        podano; przy liście Values co najmniej jedna wartość). Zwraca obiekt Valid, Value, Problem
        (komunikat po polsku); nie rzuca wyjątków.

    .PARAMETER Schema
        Schemat parametru z manifestu (Type, Default, opcjonalnie Values).

    .PARAMETER Value
        Sprawdzana wartość.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [Collections.IDictionary] $Schema,

        [AllowNull()]
        [object] $Value
    )

    $result = {
        param([bool] $Valid, $Converted, [string] $Problem)
        [pscustomobject]@{ Valid = $Valid; Value = $Converted; Problem = $Problem }
    }
    $values = $(if ($Schema.Contains('Values')) { @($Schema['Values'] | ForEach-Object { [string]$_ }) } else { $null })
    switch ([string]$Schema['Type']) {
        'Bool' {
            if ($Value -is [bool]) {
                return & $result $true $Value $null
            }
            $parsed = $false
            if ($null -ne $Value -and [bool]::TryParse([string]$Value, [ref]$parsed)) {
                return & $result $true $parsed $null
            }
            return & $result $false $null ("wartość '{0}' nie jest wartością logiczną" -f $Value)
        }
        'Int' {
            $number = 0
            if ($null -ne $Value -and $Value -isnot [bool] -and [int]::TryParse([string]$Value, [ref]$number)) {
                return & $result $true $number $null
            }
            return & $result $false $null ("wartość '{0}' nie jest liczbą całkowitą" -f $Value)
        }
        'StringArray' {
            $list = @($Value | Where-Object { $null -ne $_ } | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_ })
            if ($null -ne $values) {
                $unknown = @($list | Where-Object { $values -notcontains $_ })
                if ($unknown.Count -gt 0) {
                    return & $result $false $null ("wartości spoza listy: {0}" -f ($unknown -join ', '))
                }
                if ($list.Count -eq 0) {
                    return & $result $false $null 'brak wybranej wartości'
                }
            }
            return & $result $true ([string[]]$list) $null
        }
        default {
            if ($null -eq $Value -or $Value -is [Collections.IDictionary] -or ($Value -is [array])) {
                return & $result $false $null 'wartość nie jest tekstem'
            }
            $text = [string]$Value
            if ($null -ne $values -and $values -notcontains $text) {
                return & $result $false $null ("wartość '{0}' spoza listy" -f $text)
            }
            return & $result $true $text $null
        }
    }
}
