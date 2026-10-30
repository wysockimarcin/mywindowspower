function Update-MwpStatusInstance {
    <#
    .SYNOPSIS
        Pokazuje na pasku stanu instancję widoczną w oknie głównym: nazwę, komputer i stan połączenia.

    .DESCRIPTION
        Pasek stanu dotyczy wyłącznie instancji pokazanej w kontenerze widoku; nie ma globalnego
        „bieżącego komputera" (D-019). Dla innych widoków sekcja instancji jest ukryta.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Zmienia tylko kontrolki okna.')]
    [CmdletBinding()]
    param()

    $ui = $script:MwpUi
    $c = $ui.Controls
    $key = [string]$ui.CurrentKey
    $entry = $null
    if ($key.StartsWith('instance:')) {
        $entry = $ui.Instances[$key.Substring(9)]
    }
    if ($null -eq $entry) {
        $c['StatusInstancePanel'].Visibility = 'Collapsed'
        return
    }
    $context = $entry.Instance.Context
    $c['StatusInstance'].Text = 'Instancja: {0} · komputer: {1}' -f $entry.Instance.Name, (Format-MwpTargetLabel -Context $context)
    $c['StatusInstanceBadge'].DataContext = Get-MwpConnectionStateInfo -Context $context
    $c['StatusInstancePanel'].Visibility = 'Visible'
}
