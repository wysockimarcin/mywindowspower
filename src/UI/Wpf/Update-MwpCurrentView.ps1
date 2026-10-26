function Update-MwpCurrentView {
    <#
    .SYNOPSIS
        Odświeża dane widoku pokazanego w oknie głównym (bez ponownego tworzenia kontrolek).
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Zmienia tylko kontrolki okna.')]
    [CmdletBinding()]
    param()

    $ui = $script:MwpUi
    $key = [string]$ui.CurrentKey
    if ($key.StartsWith('instance:')) {
        $entry = $ui.Instances[$key.Substring(9)]
        if ($null -ne $entry) {
            Update-MwpInstanceView -Entry $entry
        }
        return
    }
    $view = $ui.Views[$key]
    if ($null -eq $view) {
        return
    }
    switch -Wildcard ($key) {
        'dashboard' { Update-MwpDashboardView -View $view }
        'area:*' { Update-MwpAreaView -View $view }
        'modules' { Update-MwpModulesView -View $view }
        'settings' { Update-MwpSettingsView -View $view }
        'about' { Update-MwpAboutView -View $view }
    }
}
