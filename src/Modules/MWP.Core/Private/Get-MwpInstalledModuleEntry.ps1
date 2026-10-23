function Get-MwpInstalledModuleEntry {
    <#
    .SYNOPSIS
        Czyta surowe wpisy rejestru modułów z paczek (installedModules) jako listę słowników.

    .PARAMETER Settings
        Ustawienia już odczytane przez wywołującego (bez ponownego czytania pliku).
    #>
    [CmdletBinding()]
    [OutputType([Collections.IDictionary])]
    param(
        [Collections.IDictionary] $Settings
    )

    if ($null -eq $Settings) {
        $Settings = (Read-MwpSettingsData).Settings
    }
    if (-not $Settings.Contains('installedModules') -or $null -eq $Settings['installedModules']) {
        return
    }
    foreach ($entry in @($Settings['installedModules'])) {
        if ($entry -is [Collections.IDictionary]) {
            $entry
        }
    }
}
