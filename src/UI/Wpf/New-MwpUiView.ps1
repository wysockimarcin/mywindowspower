function New-MwpUiView {
    <#
    .SYNOPSIS
        Tworzy widok okna głównego dla klucza nawigacji (XAML z Views\ i podpięcie zdarzeń).

    .PARAMETER Key
        dashboard, area:<Id>, modules, settings albo about.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Tworzy tylko kontrolki okna.')]
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Key
    )

    $ui = $script:MwpUi
    $file = switch -Wildcard ($Key) {
        'dashboard' { 'Dashboard.xaml' }
        'area:*' { 'Area.xaml' }
        'modules' { 'Modules.xaml' }
        'settings' { 'Settings.xaml' }
        'about' { 'About.xaml' }
        default { $null }
    }
    if ($null -eq $file) {
        Write-Warning ("Nieznany widok '{0}'." -f $Key)
        return $null
    }
    $view = Import-MwpXaml -Path (Join-Path -Path $ui.UiRoot -ChildPath ('Views\{0}' -f $file))
    $view | Add-Member -NotePropertyName Key -NotePropertyValue $Key
    switch -Wildcard ($Key) {
        'dashboard' { Initialize-MwpDashboardView -View $view }
        'area:*' { Initialize-MwpAreaView -View $view }
        'modules' { Initialize-MwpModulesView -View $view }
        'settings' { Initialize-MwpSettingsView -View $view }
        'about' { Initialize-MwpAboutView -View $view }
    }
    $view
}
