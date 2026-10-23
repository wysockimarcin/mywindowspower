function Get-MwpProtectedItem {
    <#
    .SYNOPSIS
        Zwraca elementy z listy ochronnej (elementy krytyczne, domyślnie zablokowane przed zmianą).

    .DESCRIPTION
        Dane leżą w osobnym pliku Data\protected-items.json modułu MWP.Core. Pole name może
        zawierać symbole wieloznaczne (-like). Porównanie nie rozróżnia wielkości liter.

    .PARAMETER Category
        Kategoria elementu, np. Service.

    .PARAMETER Name
        Nazwa sprawdzanego elementu; zwracane są wpisy, których wzorzec do niej pasuje.

    .EXAMPLE
        Get-MwpProtectedItem -Category Service -Name 'RpcSs'
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [ValidateNotNullOrEmpty()]
        [string] $Category,

        [ValidateNotNullOrEmpty()]
        [string] $Name
    )

    $path = Get-MwpProtectedListPath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw ("Nie znaleziono pliku listy ochronnej {0}." -f $path)
    }
    $data = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json

    foreach ($item in @($data.items)) {
        if ($PSBoundParameters.ContainsKey('Category') -and $item.category -ne $Category) {
            continue
        }
        if ($PSBoundParameters.ContainsKey('Name') -and -not ($Name -like $item.name)) {
            continue
        }
        [pscustomobject]@{
            PSTypeName = 'MWP.ProtectedItem'
            Category   = [string]$item.category
            Name       = [string]$item.name
            Reason     = [string]$item.reason
        }
    }
}
