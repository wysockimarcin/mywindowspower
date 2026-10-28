function Get-MwpUpdateModuleInfo {
    <#
    .SYNOPSIS
        Zwraca informacje o module MWP.Update.

    .DESCRIPTION
        Punkt wejścia kontraktu modułu (D-024). Nie zmienia systemu.

    .EXAMPLE
        Get-MwpUpdateModuleInfo
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $module = $MyInvocation.MyCommand.Module
    [pscustomobject]@{
        Name    = $module.Name
        Version = $module.Version
        Status  = 'Windows Update: stan i usługi, wyszukiwanie (COM), historia, pauza z cofaniem, reset składników, instalacja lokalna (FAZA 10)'
    }
}
