function Get-MwpStartupModuleInfo {
    <#
    .SYNOPSIS
        Zwraca informacje o module MWP.Startup.

    .DESCRIPTION
        Zaślepka z FAZY 1. Potwierdza, że moduł się ładuje. Nie zmienia systemu.

    .EXAMPLE
        Get-MwpStartupModuleInfo
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $module = $MyInvocation.MyCommand.Module
    [pscustomobject]@{
        Name    = $module.Name
        Version = $module.Version
        Status  = 'Zaślepka'
    }
}