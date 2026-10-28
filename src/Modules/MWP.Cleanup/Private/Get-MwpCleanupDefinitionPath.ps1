function Get-MwpCleanupDefinitionPath {
    <#
    .SYNOPSIS
        Zwraca ścieżkę pliku danych z definicjami kategorii czyszczenia (Data\cleanup-categories.json).

    .DESCRIPTION
        Jedno miejsce znające położenie pliku (w testach podmieniane mockiem).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    Join-Path -Path (Split-Path -Parent $PSScriptRoot) -ChildPath 'Data\cleanup-categories.json'
}
