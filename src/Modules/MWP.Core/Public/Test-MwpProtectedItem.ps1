function Test-MwpProtectedItem {
    <#
    .SYNOPSIS
        Sprawdza, czy element jest na liście ochronnej.

    .DESCRIPTION
        Funkcje zmieniające system wywołują ją przed zmianą elementu i domyślnie odmawiają
        zmiany elementu chronionego (wzorzec w ARCHITEKTURA.md). Powód ochrony zwraca
        Get-MwpProtectedItem.

    .OUTPUTS
        [bool]

    .EXAMPLE
        Test-MwpProtectedItem -Category Service -Name 'RpcSs'
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Category,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name
    )

    $null -ne (Get-MwpProtectedItem -Category $Category -Name $Name | Select-Object -First 1)
}
