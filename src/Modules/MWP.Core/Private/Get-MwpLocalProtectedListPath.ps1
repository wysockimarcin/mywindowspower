function Get-MwpLocalProtectedListPath {
    <#
    .SYNOPSIS
        Zwraca ścieżkę lokalnego rozszerzenia listy ochronnej (protected.local.json obok settings.local.json).

    .DESCRIPTION
        Plik jest poza repozytorium (config\ albo katalog zapasowy %LOCALAPPDATA%\MyWindowsPower,
        jak ustawienia lokalne — D-032, D-045). Może go nie być. Zwraca $null, gdy ścieżki
        konfiguracji nie da się ustalić.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    try {
        $settings = (Get-MwpConfigPath).Local
    }
    catch {
        Write-Verbose ("Brak ścieżki konfiguracji: {0}" -f $_.Exception.Message)
        return $null
    }
    Join-Path -Path (Split-Path -Path $settings -Parent) -ChildPath 'protected.local.json'
}
