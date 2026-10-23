function New-MwpReadOnlyObject {
    <#
    .SYNOPSIS
        Tworzy obiekt, którego właściwości są tylko do odczytu (próba przypisania kończy się błędem).

    .DESCRIPTION
        Każda właściwość to zmienna PowerShella z opcją ReadOnly (PSVariableProperty). W odróżnieniu
        od właściwości skryptowych nie wykonuje kodu przy odczycie, więc obiekt można bezpiecznie
        czytać w innych runspace'ach (D-023). Używane przez kontekst wykonania (niezmienny, D-019).
        Wartości złożone (słowniki) wywołujący przekazuje już jako kolekcje tylko do odczytu.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Tworzy tylko obiekt w pamięci; nie zmienia stanu systemu.')]
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $TypeName,

        [Parameter(Mandatory)]
        [Collections.IDictionary] $Property
    )

    $object = [pscustomobject]@{}
    $object.PSObject.TypeNames.Insert(0, $TypeName)
    foreach ($name in $Property.Keys) {
        $variable = [Management.Automation.PSVariable]::new([string]$name, $Property[$name], [Management.Automation.ScopedItemOptions]::ReadOnly)
        $object.PSObject.Properties.Add([Management.Automation.PSVariableProperty]::new($variable))
    }
    $object
}
