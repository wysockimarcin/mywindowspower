function Get-MwpModuleViewCatalog {
    <#
    .SYNOPSIS
        Zwraca katalog własnych widoków modułów wbudowanych: Id modułu, plik XAML i funkcje inicjalizacji i odświeżenia widoku.

    .DESCRIPTION
        Widoki modułów wbudowanych należą do hosta (src\UI\Views, D-044) — moduł logiki nie zależy
        od WPF (granica warstw D-015, D-039). Instancja modułu z wpisem w katalogu dostaje widok
        instancji (nagłówek, stan połączenia, przyciski) z widokiem modułu w miejscu zaślepki; moduł
        bez wpisu — dotychczasowy widok ogólny. Funkcje widoku przyjmują -Entry (wpis instancji okna).

    .PARAMETER ModuleId
        Zwraca tylko wpis tego modułu.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [ValidateNotNullOrEmpty()]
        [string] $ModuleId
    )

    $views = @(
        [pscustomobject]@{ PSTypeName = 'MWP.UiModuleView'; ModuleId = 'Power'; View = 'Views\Power.xaml'; Initialize = 'Initialize-MwpPowerView'; Update = 'Update-MwpPowerView' }
    )
    foreach ($view in $views) {
        if (-not $PSBoundParameters.ContainsKey('ModuleId') -or $view.ModuleId -eq $ModuleId) {
            $view
        }
    }
}
