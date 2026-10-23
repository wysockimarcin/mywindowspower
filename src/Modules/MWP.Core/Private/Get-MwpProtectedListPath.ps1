function Get-MwpProtectedListPath {
    <#
    .SYNOPSIS
        Zwraca ścieżkę pliku danych listy ochronnej (Data\protected-items.json w module).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    Join-Path -Path (Split-Path -Parent $PSScriptRoot) -ChildPath 'Data\protected-items.json'
}
