function Write-MwpLocalSetting {
    <#
    .SYNOPSIS
        Zapisuje wartości w pliku ustawień lokalnych (atomowo), bez logu i bez wpisu cofnięcia.

    .DESCRIPTION
        Wspólny zapis dla Set-MwpSetting i funkcji rdzenia, które same prowadzą log i decydują
        o cofaniu (np. rejestr modułów z paczek, D-031). Plik dostaje bieżącą schemaVersion
        z szablonu i zachowuje pozostałe nadpisania (po migracji). Pierwszy zapis przy
        niezapisywalnym folderze config trafia do katalogu zapasowego (D-032).
        Klucze spoza szablonu są odrzucane (błąd programisty).

    .PARAMETER Values
        Słownik: nazwa ustawienia -> nowa wartość.

    .PARAMETER Data
        Wynik Read-MwpSettingsData, gdy wywołujący już go ma (bez ponownego czytania pliku).
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Funkcja wewnętrzna; potwierdzenie i podgląd obsługuje funkcja publiczna, która ją wywołuje.')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Collections.IDictionary] $Values,

        [Collections.IDictionary] $Data
    )

    if ($null -eq $Data) {
        $Data = Read-MwpSettingsData
    }
    foreach ($name in $Values.Keys) {
        if ($name -eq 'schemaVersion' -or -not $Data.Defaults.Contains($name)) {
            throw ("Nieznane lub niedozwolone ustawienie '{0}'." -f $name)
        }
    }

    $local = [ordered]@{ schemaVersion = $Data.Defaults['schemaVersion'] }
    foreach ($key in $Data.Local.Keys) {
        if ($key -ne 'schemaVersion') {
            $local[$key] = $Data.Local[$key]
        }
    }
    foreach ($name in $Values.Keys) {
        $local[$name] = $Values[$name]
    }

    $localPath = $Data.Paths.Local
    if (-not (Test-Path -LiteralPath $localPath)) {
        $localPath = (Get-MwpConfigPath -ForWrite).Local
    }
    Write-MwpJsonFile -Path $localPath -InputObject $local
}
