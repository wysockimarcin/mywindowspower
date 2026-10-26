function Update-MwpModuleCatalog {
    <#
    .SYNOPSIS
        Odkrywa moduły na nowo (Get-MwpModuleDefinition) i odświeża nawigację oraz bieżący widok.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Zmienia tylko stan okna (lista definicji w pamięci).')]
    [CmdletBinding()]
    param()

    $ui = $script:MwpUi
    $ui.Definitions = @(Get-MwpModuleDefinition)
    Update-MwpNavigation
    Update-MwpCurrentView
}
