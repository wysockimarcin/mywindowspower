function Get-MwpModuleInstance {
    <#
    .SYNOPSIS
        Zwraca otwarte instancje modułów z rejestru instancji procesu.

    .PARAMETER Id
        Identyfikator instancji.

    .PARAMETER ModuleId
        Id modułu albo nazwa jego folderu.

    .PARAMETER ComputerName
        Komputer docelowy kontekstu instancji.

    .EXAMPLE
        Get-MwpModuleInstance -ModuleId 'Services' | Select-Object Name, Status, @{ n = 'Stan'; e = { $_.Context.Connection.State } }
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [ValidateNotNullOrEmpty()]
        [string] $Id,

        [ValidateNotNullOrEmpty()]
        [string] $ModuleId,

        [ValidateNotNullOrEmpty()]
        [string] $ComputerName
    )

    $bound = $PSBoundParameters
    @($script:MwpInstanceRegistry.Values) |
        Where-Object {
            (-not $bound.ContainsKey('Id') -or $_.Id -eq $Id) -and
            (-not $bound.ContainsKey('ModuleId') -or $_.ModuleId -eq $ModuleId -or $_.ModuleName -eq $ModuleId) -and
            (-not $bound.ContainsKey('ComputerName') -or $_.Context.ComputerName -eq $ComputerName)
        } |
        Sort-Object -Property CreatedAt
}
