function Initialize-MwpDashboardView {
    <#
    .SYNOPSIS
        Podpina widok Pulpitu (zaślepka Dashboardu z FAZY 5): dodawanie komputera i lista instancji.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '',
        Justification = 'Parametry obsługi zdarzeń WPF są używane w zagnieżdżonych blokach (Invoke-MwpUiSafe -Action), czego reguła nie widzi.')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $View
    )

    $View.Controls['AddTargetButton'].Add_Click({
            param($control)
            Invoke-MwpUiSafe -Name 'UI.Target.Add' -Action { Edit-MwpUiTarget -Owner (Get-MwpOwnerWindow -Element $control) }
        })
    Register-MwpUiInstanceListHandler -List $View.Controls['InstancesList']
}
