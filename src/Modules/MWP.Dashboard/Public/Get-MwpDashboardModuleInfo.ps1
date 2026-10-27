function Get-MwpDashboardModuleInfo {
    <#
    .SYNOPSIS
        Zwraca informacje o module MWP.Dashboard.

    .DESCRIPTION
        Funkcja wejścia kontraktu modułu. Moduł dostarcza odczyt informacji o systemie
        (Get-MwpSystemInfo), widget „Informacje o systemie” i eksport raportu (FAZA 5).
        Nie zmienia systemu.

    .EXAMPLE
        Get-MwpDashboardModuleInfo
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $module = $MyInvocation.MyCommand.Module
    [pscustomobject]@{
        Name    = $module.Name
        Version = $module.Version
        Status  = 'Gotowy'
    }
}
