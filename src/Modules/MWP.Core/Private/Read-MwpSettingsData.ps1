function Read-MwpSettingsData {
    <#
    .SYNOPSIS
        Czyta ustawienia: wartości domyślne z szablonu i nadpisania z pliku lokalnego.

    .DESCRIPTION
        Nie loguje (żeby Write-MwpLog mógł z niej korzystać bez rekurencji); ostrzeżenia zwraca
        w polu Warnings. Uszkodzony plik lokalny nie blokuje startu: zostaje przeniesiony pod nazwę
        z sufiksem .corrupt-<data>, a zwracane są wartości domyślne (D-015). Z -NoRepair plik
        nie jest przenoszony (używa tego logowanie, żeby ostrzeżenie zobaczył Get-MwpSetting).

    .OUTPUTS
        Hashtable: Settings, Defaults, Local (uporządkowane słowniki), Warnings, Paths.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [switch] $NoRepair
    )

    $paths = Get-MwpConfigPath
    $warnings = New-Object -TypeName System.Collections.Generic.List[string]

    $defaults = [ordered]@{}
    if (Test-Path -LiteralPath $paths.Example) {
        $defaults = ConvertTo-MwpHashtable -InputObject (Get-Content -LiteralPath $paths.Example -Raw -Encoding UTF8 | ConvertFrom-Json)
    }
    else {
        $warnings.Add(("Brak szablonu ustawień: {0}." -f $paths.Example))
    }

    $local = [ordered]@{}
    if (Test-Path -LiteralPath $paths.Local) {
        $raw = Get-Content -LiteralPath $paths.Local -Raw -Encoding UTF8
        if (-not [string]::IsNullOrWhiteSpace($raw)) {
            try {
                $parsed = $raw | ConvertFrom-Json -ErrorAction Stop
                if ($parsed -isnot [Management.Automation.PSCustomObject]) {
                    throw 'plik nie zawiera obiektu JSON'
                }
                $local = ConvertTo-MwpHashtable -InputObject $parsed
            }
            catch {
                $local = [ordered]@{}
                if ($NoRepair) {
                    $warnings.Add(("Plik ustawień {0} jest uszkodzony; użyto wartości domyślnych." -f $paths.Local))
                }
                else {
                    $backup = '{0}.corrupt-{1:yyyyMMdd-HHmmss}' -f $paths.Local, (Get-Date)
                    Move-Item -LiteralPath $paths.Local -Destination $backup -Force
                    $warnings.Add(("Plik ustawień {0} był uszkodzony ({1}). Zachowano go jako {2}; użyto wartości domyślnych." -f
                            $paths.Local, $_.Exception.Message, $backup))
                }
            }
        }
    }

    $targetVersion = $defaults['schemaVersion']
    if ($local.Contains('schemaVersion') -and $null -ne $targetVersion -and $local['schemaVersion'] -ne $targetVersion) {
        if ($local['schemaVersion'] -gt $targetVersion) {
            $warnings.Add(("Plik ustawień ma nowszą wersję schematu ({0}) niż obsługiwana ({1}); użyto wartości domyślnych, plik pozostał bez zmian." -f
                    $local['schemaVersion'], $targetVersion))
            $local = [ordered]@{}
        }
        else {
            $migration = Invoke-MwpSettingsMigration -Settings $local -TargetVersion $targetVersion
            $local = $migration.Settings
            foreach ($message in $migration.Warnings) {
                $warnings.Add($message)
            }
        }
    }

    $settings = [ordered]@{}
    foreach ($key in $defaults.Keys) {
        $settings[$key] = $defaults[$key]
    }
    foreach ($key in $local.Keys) {
        if ($key -eq 'schemaVersion') {
            continue
        }
        if ($defaults.Contains($key)) {
            $settings[$key] = $local[$key]
        }
        else {
            $warnings.Add(("Nieznane ustawienie '{0}' w pliku lokalnym zostało pominięte." -f $key))
        }
    }

    @{
        Settings = $settings
        Defaults = $defaults
        Local    = $local
        Warnings = $warnings.ToArray()
        Paths    = $paths
    }
}
