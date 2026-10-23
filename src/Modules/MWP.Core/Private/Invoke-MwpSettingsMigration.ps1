function Invoke-MwpSettingsMigration {
    <#
    .SYNOPSIS
        Podnosi ustawienia lokalne do bieżącej wersji schematu (schemaVersion).

    .DESCRIPTION
        Każdy krok migracji zamienia wersję N na N+1. Przy zmianie schematu w szablonie dopisz
        krok do tabeli $steps (klucz = wersja źródłowa). Brak kroku: ustawienia zostają bez
        migracji, a zwracane jest ostrzeżenie. Funkcja nie zapisuje pliku; zapis następuje
        przy najbliższym Set-MwpSetting.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [Collections.IDictionary] $Settings,

        [Parameter(Mandatory)]
        [int] $TargetVersion
    )

    # Krok 1 -> 2 (FAZA 3): komputery docelowe (targets), rejestr modułów z paczek (installedModules)
    # i ustawienia modułów (modules). Pozostałe klucze, w tym dataPath (D-032), zostają bez zmian.
    $steps = @{
        1 = {
            param($Data)
            foreach ($key in 'targets', 'installedModules') {
                if (-not $Data.Contains($key)) {
                    $Data[$key] = @()
                }
            }
            if (-not $Data.Contains('modules')) {
                $Data['modules'] = [ordered]@{}
            }
            $Data
        }
    }

    $warnings = New-Object -TypeName System.Collections.Generic.List[string]
    $current = [int]$Settings['schemaVersion']
    while ($current -lt $TargetVersion) {
        if (-not $steps.ContainsKey($current)) {
            $warnings.Add(("Brak migracji ustawień z wersji schematu {0} do {1}; użyto zgodnych wartości bez migracji." -f
                    $current, $TargetVersion))
            break
        }
        $Settings = & $steps[$current] $Settings
        $current++
        $Settings['schemaVersion'] = $current
    }

    @{
        Settings = $Settings
        Warnings = $warnings.ToArray()
    }
}
