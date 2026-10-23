function Get-MwpTweaksModuleInfo {
    <#
    .SYNOPSIS
        Zwraca informacje o module MWP.Tweaks.

    .DESCRIPTION
        Zaślepka z FAZY 1. Potwierdza, że moduł się ładuje. Nie zmienia systemu.

    .EXAMPLE
        Get-MwpTweaksModuleInfo
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