function Resolve-MwpDataPath {
    <#
    .SYNOPSIS
        Zamienia wartość ustawienia dataPath na pełną ścieżkę katalogu danych (bez sprawdzania zapisywalności).

    .DESCRIPTION
        Zasady D-032: pusta wartość = <folder aplikacji>\data; ścieżka względna jest liczona od folderu
        aplikacji; ścieżka bezwzględna (dysk lub UNC) może zawierać zmienne środowiskowe. Nieznana
        zmienna i ścieżka zależna od bieżącego dysku lub katalogu ('C:dane', '\dane') kończą się
        wyjątkiem z opisem po polsku. Używają jej Get-MwpDataPath (bieżący katalog danych)
        i Get-MwpDataLocation (podgląd nowej wartości w Ustawieniach).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [string] $Value
    )

    $configured = ''
    if ($null -ne $Value) {
        $configured = $Value.Trim()
    }
    $appRoot = Get-MwpProjectRoot
    if ($configured -eq '') {
        return [IO.Path]::GetFullPath([IO.Path]::Combine($appRoot, 'data'))
    }

    $expanded = [Environment]::ExpandEnvironmentVariables($configured)
    if ($expanded -match '%[^%\\/]+%') {
        throw ("nieznana zmienna środowiskowa w '{0}'" -f $configured)
    }
    if ($expanded.IndexOfAny([IO.Path]::GetInvalidPathChars()) -ge 0) {
        throw ("ścieżka '{0}' zawiera niedozwolone znaki" -f $configured)
    }
    if ($expanded -match '^(?:[A-Za-z]:[\\/]|[\\/]{2})') {
        $candidate = $expanded
    }
    elseif ($expanded -match '^(?:[A-Za-z]:|[\\/])') {
        # 'C:dane' i '\dane' zależą od bieżącego dysku lub katalogu procesu.
        throw ("ścieżka '{0}' nie jest ani względna, ani pełna" -f $configured)
    }
    else {
        $candidate = [IO.Path]::Combine($appRoot, $expanded)
    }
    [IO.Path]::GetFullPath($candidate)
}
