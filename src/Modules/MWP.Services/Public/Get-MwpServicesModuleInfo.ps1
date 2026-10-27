function Get-MwpServicesModuleInfo {
    <#
    .SYNOPSIS
        Zwraca informacje o module MWP.Services.

    .DESCRIPTION
        Funkcja wejścia kontraktu modułu (EntryPoint, D-024). Nie zmienia systemu.

    .EXAMPLE
        Get-MwpServicesModuleInfo
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $module = $MyInvocation.MyCommand.Module
    [pscustomobject]@{
        Name    = $module.Name
        Version = $module.Version
        Status  = 'Usługi Windows: lista, start/stop/restart, typ uruchomienia, lista ochronna, profile (FAZA 7)'
    }
}
