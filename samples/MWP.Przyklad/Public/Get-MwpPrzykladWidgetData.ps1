function Get-MwpPrzykladWidgetData {
    <#
    .SYNOPSIS
        Funkcja danych widgetu przykładowego (kontrakt widgetu, D-043): informacje o komputerze docelowym w tle.

    .DESCRIPTION
        Operacja klasy Odczyt. Zwraca uchwyt operacji (Get-MwpTargetInfo -AsOperation); widok przygotowuje
        ConvertTo-MwpPrzykladWidgetView. Parametry widgetu nie są używane.

    .EXAMPLE
        Get-MwpPrzykladWidgetData -Context (New-MwpExecutionContext) -AsOperation | Wait-MwpOperation
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '',
        Justification = 'Sygnatura kontraktu widgetu: -AsOperation i -WidgetParameters są wymagane, choć przykład ich nie używa.')]
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [PSTypeName('MWP.ExecutionContext')]
        [object] $Context,

        [switch] $AsOperation,

        [AllowNull()]
        [Collections.IDictionary] $WidgetParameters
    )

    Get-MwpTargetInfo -Context $Context -AsOperation
}
