function Get-MwpPowerModuleInfo {
    <#
    .SYNOPSIS
        Zwraca informacje o module MWP.Power.

    .DESCRIPTION
        Funkcja wejścia kontraktu modułu (EntryPoint, D-024). Nie zmienia systemu.

    .EXAMPLE
        Get-MwpPowerModuleInfo
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $module = $MyInvocation.MyCommand.Module
    [pscustomobject]@{
        Name    = $module.Name
        Version = $module.Version
        Status  = 'Plany zasilania, ustawienia energii i raporty (FAZA 6)'
    }
}
