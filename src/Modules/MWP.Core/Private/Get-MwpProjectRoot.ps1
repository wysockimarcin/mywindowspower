function Get-MwpProjectRoot {
    <#
    .SYNOPSIS
        Zwraca katalog główny repozytorium (wyznaczony z położenia modułu, bez ścieżek bezwzględnych).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    # Private\ -> MWP.Core\ -> Modules\ -> src\ -> katalog główny.
    [IO.Path]::GetFullPath((Join-Path -Path $PSScriptRoot -ChildPath '..\..\..\..'))
}
