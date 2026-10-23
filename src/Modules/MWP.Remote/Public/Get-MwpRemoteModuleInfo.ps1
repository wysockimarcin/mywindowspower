function Get-MwpRemoteModuleInfo {
    <#
    .SYNOPSIS
        Zwraca informacje o module MWP.Remote: wersję, liczbę instancji modułów i operacji w toku.

    .EXAMPLE
        Get-MwpRemoteModuleInfo
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $module = $MyInvocation.MyCommand.Module
    [pscustomobject]@{
        Name              = $module.Name
        Version           = $module.Version
        Status            = 'Gotowy'
        Instances         = $script:MwpInstanceRegistry.Count
        RunningOperations = @($script:MwpOperationRegistry.Values | Where-Object { $_.Status -eq 'Running' }).Count
    }
}
