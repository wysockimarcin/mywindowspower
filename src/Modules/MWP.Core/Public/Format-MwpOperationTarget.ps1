function Format-MwpOperationTarget {
    <#
    .SYNOPSIS
        Buduje opis celu operacji z nazwą komputera, do ShouldProcess i potwierdzeń.

    .DESCRIPTION
        Potwierdzenie operacji zmieniającej system zawsze zawiera nazwę komputera docelowego
        (D-019), także dla 'localhost', żeby komunikat był jednoznaczny.

    .EXAMPLE
        Format-MwpOperationTarget -Target "usługa 'Spooler'" -ComputerName 'localhost'
        # usługa 'Spooler' — komputer: localhost
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Target,

        [ValidateNotNullOrEmpty()]
        [string] $ComputerName = 'localhost'
    )

    '{0} — komputer: {1}' -f $Target, $ComputerName
}
