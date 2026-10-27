function Get-MwpStartupModuleInfo {
    <#
    .SYNOPSIS
        Zwraca informacje o module MWP.Startup.

    .DESCRIPTION
        Funkcja wejścia kontraktu modułu (EntryPoint, D-024). Nie zmienia systemu.

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
        Status  = 'Autostart (Run/RunOnce, foldery Startup, StartupApproved) i harmonogram zadań: włącz/wyłącz, uruchom, usuń z eksportem XML, podpis wydawcy (FAZA 8)'
    }
}
