function Initialize-MwpAreaView {
    <#
    .SYNOPSIS
        Podpina widok obszaru: „Otwórz instancję…" (wybór komputera) i lista instancji modułu.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '',
        Justification = 'Parametry obsługi zdarzeń WPF są używane w zagnieżdżonych blokach (Invoke-MwpUiSafe -Action), czego reguła nie widzi.')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $View
    )

    $View.Controls['OpenInstanceButton'].Tag = $View.Key.Substring(5)
    $View.Controls['OpenInstanceButton'].Add_Click({
            param($control)
            Invoke-MwpUiSafe -Name 'UI.Instance.Open' -Action {
                $moduleId = [string]$control.Tag
                $definition = @($script:MwpUi.Definitions | Where-Object { $_.Id -eq $moduleId }) | Select-Object -First 1
                if ($null -ne $definition) {
                    Open-MwpUiInstance -Definition $definition -Owner (Get-MwpOwnerWindow -Element $control)
                }
            }
        })
    Register-MwpUiInstanceListHandler -List $View.Controls['InstancesList']
}
