function Get-MwpAppsModuleInfo {
    <#
    .SYNOPSIS
        Zwraca informacje o module MWP.Apps.

    .DESCRIPTION
        Zaślepka z FAZY 1. Potwierdza, że moduł się ładuje. Nie zmienia systemu.

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
        Status  = 'Zaślepka'
    }
}