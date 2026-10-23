function Test-MwpSettingValueType {
    <#
    .SYNOPSIS
        Sprawdza, czy nowa wartość ustawienia ma typ zgodny z wartością domyślną z szablonu.

    .DESCRIPTION
        Liczby całkowite i zmiennoprzecinkowe są zgodne między sobą, bo ConvertFrom-Json zwraca
        [int] w 5.1 i [long] w 7.x. Dla tablic i obiektów typ nie jest sprawdzany.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [AllowNull()]
        [object] $Default,

        [AllowNull()]
        [object] $Value
    )

    $numericTypes = @([byte], [int16], [int], [long], [uint16], [uint32], [uint64], [single], [double], [decimal])
    $isNumber = {
        param($Item)
        if ($null -eq $Item) {
            return $false
        }
        foreach ($type in $numericTypes) {
            if ($Item -is $type) {
                return $true
            }
        }
        $false
    }

    if ($null -eq $Default) {
        return $true
    }
    if ($Default -is [bool]) {
        return $Value -is [bool]
    }
    if (& $isNumber $Default) {
        return [bool](& $isNumber $Value)
    }
    if ($Default -is [string]) {
        return $Value -is [string]
    }
    $true
}
