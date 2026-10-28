function Get-MwpNetworkModuleInfo {
    <#
    .SYNOPSIS
        Zwraca informacje o module MWP.Network.

    .DESCRIPTION
        Punkt wejścia kontraktu modułu (D-024). Nie zmienia systemu.

    .EXAMPLE
        Get-MwpNetworkModuleInfo
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $module = $MyInvocation.MyCommand.Module
    [pscustomobject]@{
        Name    = $module.Name
        Version = $module.Version
        Status  = 'Sieć: adaptery i konfiguracja IP, DNS z presetami, cofaniem i automatycznym wycofaniem, flush DNS, DHCP, resety Winsock/IP, testy łączności (FAZA 11)'
    }
}
