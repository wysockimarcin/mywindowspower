function Get-MwpProtectedItem {
    <#
    .SYNOPSIS
        Zwraca elementy z listy ochronnej (elementy krytyczne, domyślnie zablokowane przed zmianą).

    .DESCRIPTION
        Dane leżą w osobnym pliku Data\protected-items.json modułu MWP.Core (Source = BuiltIn).
        Opcjonalny plik lokalny protected.local.json obok settings.local.json (poza repozytorium,
        ten sam format) może tylko DODAWAĆ elementy chronione (Source = Local, D-045); nieczytelny
        plik lokalny jest pomijany z ostrzeżeniem, a brak pliku wbudowanego jest błędem. Pole name
        może zawierać symbole wieloznaczne (-like). Porównanie nie rozróżnia wielkości liter.

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
    $sources = @([pscustomobject]@{ Source = 'BuiltIn'; Items = @((Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json).items) })
    $localPath = Get-MwpLocalProtectedListPath
    if ($localPath -and (Test-Path -LiteralPath $localPath -PathType Leaf)) {
        try {
            $local = Get-Content -LiteralPath $localPath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
            $sources += [pscustomobject]@{ Source = 'Local'; Items = @($local.items | Where-Object { $null -ne $_ -and $_.category -and $_.name }) }
        }
        catch {
            Write-Warning ("Pominięto lokalną listę ochronną {0}: {1}" -f $localPath, $_.Exception.Message)
        }
    }

    foreach ($source in $sources) {
        foreach ($item in @($source.Items)) {
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
                Source     = $source.Source
            }
        }
    }
}
