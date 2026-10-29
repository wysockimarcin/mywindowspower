function Get-MwpAppsModuleInfo {
    <#
    .SYNOPSIS
        Zwraca informacje o module MWP.Apps.

    .DESCRIPTION
        Punkt wejścia kontraktu modułu (D-024). Nie zmienia systemu.

    .EXAMPLE
        Get-MwpAppsModuleInfo
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $module = $MyInvocation.MyCommand.Module
    [pscustomobject]@{
        Name    = $module.Name
        Version = $module.Version
        Status  = 'Aplikacje: programy z rejestru i pakiety Appx, winget (lista, aktualizacje, wyszukiwanie, instalacja), odinstalowanie z listą ochronną (FAZA 12)'
    }
}