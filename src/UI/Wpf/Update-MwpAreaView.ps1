function Update-MwpAreaView {
    <#
    .SYNOPSIS
        Odświeża widok obszaru: opis, stan modułu (istnieje / planowany w fazie N), lista instancji.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Zmienia tylko kontrolki okna.')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $View
    )

    $ui = $script:MwpUi
    $v = $View.Controls
    $moduleId = $View.Key.Substring(5)
    $navigation = @(Get-MwpNavigationItem -Definition $ui.Definitions | Where-Object { $_.Key -eq $View.Key }) | Select-Object -First 1
    if ($null -eq $navigation) {
        $v['AreaTitle'].Text = $moduleId
        $v['AreaDescription'].Text = 'Moduł nie jest już dostępny (np. został odinstalowany).'
        $v['OpenInstanceButton'].IsEnabled = $false
        $v['StatusBanner'].Visibility = 'Collapsed'
    }
    else {
        $definition = $navigation.Definition
        $v['AreaTitle'].Text = $navigation.Title
        $v['AreaDescription'].Text = $navigation.Description
        $v['PhaseBadge'].Visibility = $(if ($null -ne $navigation.Phase) { 'Visible' } else { 'Collapsed' })
        $v['PhaseText'].Text = 'FAZA {0}' -f $navigation.Phase
        $v['OpenInstanceButton'].IsEnabled = $navigation.IsAvailable
        $v['StatusBanner'].Visibility = 'Visible'
        $v['StatusText'].Text = if (-not $navigation.IsAvailable) {
            'Moduł tego obszaru jeszcze nie istnieje — powstanie w FAZIE {0}. To widok-zaślepka.' -f $navigation.Phase
        }
        else {
            $remote = if (@($definition.Capabilities) -contains 'RemoteTarget') { 'komputer lokalny i komputery zdalne' } else { 'tylko komputer lokalny (moduł nie deklaruje jeszcze RemoteTarget)' }
            $phaseText = if ($null -ne $navigation.Phase) { ' Funkcje obszaru powstaną w FAZIE {0}; instancja pokazuje widok-zaślepkę.' -f $navigation.Phase } else { '' }
            'Moduł {0} {1} ({2}). Instancje: {3}.{4}' -f $definition.ModuleName, $definition.Version,
            $(if ($definition.Source -eq 'Installed') { 'z paczki' } else { 'wbudowany' }), $remote, $phaseText
        }
    }
    $rows = @(Get-MwpUiInstanceRow -ModuleId $moduleId)
    $v['InstancesList'].ItemsSource = $rows
    $v['NoInstancesText'].Visibility = $(if ($rows.Count -eq 0) { 'Visible' } else { 'Collapsed' })
}
