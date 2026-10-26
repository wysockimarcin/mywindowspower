function Get-MwpPrzykladInfo {
    <#
    .SYNOPSIS
        Przykład funkcji obszaru: odczyt informacji o komputerze docelowym z kontekstu wykonania.

    .DESCRIPTION
        Operacja klasy Odczyt. Komputer pochodzi wyłącznie z -Context (D-019); wykonanie lokalne
        albo zdalne zapewnia MWP.Remote (Get-MwpTargetInfo).

    .EXAMPLE
        Get-MwpPrzykladInfo -Context (New-MwpExecutionContext)
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [PSTypeName('MWP.ExecutionContext')]
        [object] $Context
    )

    Get-MwpTargetInfo -Context $Context
}
