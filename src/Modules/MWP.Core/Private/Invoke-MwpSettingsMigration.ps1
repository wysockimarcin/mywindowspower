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

    # Schemat 1 jest pierwszy, więc nie ma jeszcze kroków migracji.
    $steps = @{}

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
