function Get-MwpDataPath {
    <#
    .SYNOPSIS
        Zwraca katalog danych aplikacji (logi, rejestr cofnięć) według ustawienia dataPath (D-032).

    .DESCRIPTION
        Jedyne miejsce, które zna położenie danych lokalnych. Zasady:
        - dataPath pusty (domyślnie) = <folder aplikacji>\data;
        - ścieżka względna jest liczona od folderu aplikacji (z $PSScriptRoot, nie z bieżącego katalogu);
        - ścieżka bezwzględna (dysk lub UNC) może zawierać zmienne środowiskowe, np. %USERPROFILE%;
        - katalog niezapisywalny (nie da się w nim utworzyć i usunąć pliku) albo niepoprawna ścieżka
          oznacza tryb zapasowy: %LOCALAPPDATA%\MyWindowsPower z ostrzeżeniem (pole Warning
          wyniku -Detailed; Write-MwpLog zapisuje je w logu).
        Wynik sprawdzenia zapisywalności jest pamiętany do końca procesu (Test-MwpDirectoryWritable).
        Kind Fallback zwraca katalog zapasowy bez czytania ustawień (używa go Get-MwpConfigPath).
        Testy podmieniają tę funkcję mockiem, żeby nie pisać do profilu ani do folderu aplikacji.

    .PARAMETER Settings
        Ustawienia już odczytane przez wywołującego (bez ponownego czytania pliku).

    .PARAMETER Detailed
        Zwraca obiekt MWP.DataPath (Path, Root, Configured, IsFallback, Warning) zamiast ścieżki.
    #>
    [CmdletBinding()]
    [OutputType([string], [pscustomobject])]
    param(
        [ValidateSet('Root', 'Logs', 'Undo', 'Fallback')]
        [string] $Kind = 'Root',

        [AllowNull()]
        [Collections.IDictionary] $Settings,

        [switch] $Detailed
    )

    $base = $env:LOCALAPPDATA
    $fallbackRoot = $null
    if (-not [string]::IsNullOrEmpty($base)) {
        $fallbackRoot = [IO.Path]::Combine($base, 'MyWindowsPower')
    }
    if ($Kind -eq 'Fallback') {
        if ($null -eq $fallbackRoot) {
            throw 'Zmienna środowiskowa LOCALAPPDATA nie jest ustawiona.'
        }
        return $fallbackRoot
    }

    if ($null -eq $Settings) {
        $Settings = (Read-MwpSettingsData -NoRepair).Settings
    }
    $configured = ''
    if ($Settings.Contains('dataPath') -and $null -ne $Settings['dataPath']) {
        $configured = ([string]$Settings['dataPath']).Trim()
    }

    $root = $null
    $warning = $null
    $candidate = $null
    try {
        $appRoot = Get-MwpProjectRoot
        if ($configured -eq '') {
            $candidate = [IO.Path]::Combine($appRoot, 'data')
        }
        else {
            $expanded = [Environment]::ExpandEnvironmentVariables($configured)
            if ($expanded -match '%[^%\\/]+%') {
                throw ("nieznana zmienna środowiskowa w '{0}'" -f $configured)
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
        }
        $candidate = [IO.Path]::GetFullPath($candidate)
        if (Test-MwpDirectoryWritable -Path $candidate) {
            $root = $candidate
        }
        else {
            $warning = "Katalog danych '{0}' jest niezapisywalny" -f $candidate
        }
    }
    catch {
        $warning = "Niepoprawny katalog danych (dataPath): {0}" -f $_.Exception.Message
    }

    if ($null -eq $root) {
        if ($null -eq $fallbackRoot) {
            throw ("{0}, a zmienna środowiskowa LOCALAPPDATA nie jest ustawiona." -f $warning)
        }
        $root = $fallbackRoot
        $warning = "{0}; użyto katalogu zapasowego '{1}'." -f $warning, $fallbackRoot
    }

    $path = $root
    if ($Kind -ne 'Root') {
        $path = [IO.Path]::Combine($root, $Kind.ToLowerInvariant())
    }
    if (-not $Detailed) {
        return $path
    }
    [pscustomobject]@{
        PSTypeName = 'MWP.DataPath'
        Path       = $path
        Root       = $root
        Configured = $configured
        IsFallback = $null -ne $warning
        Warning    = $warning
    }
}
