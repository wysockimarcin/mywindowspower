function Update-MwpStatusData {
    <#
    .SYNOPSIS
        Pokazuje na pasku stanu katalog danych i ostrzeżenie o trybie zapasowym (D-032).
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Zmienia tylko kontrolki okna.')]
    [CmdletBinding()]
    param()

    $c = $script:MwpUi.Controls
    $location = Get-MwpDataLocation
    if ($location.IsFallback) {
        $c['StatusData'].Text = 'Dane: tryb zapasowy ({0})' -f $location.Root
        $c['StatusData'].SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, 'Mwp.Brush.Danger')
        $c['StatusData'].ToolTip = $location.Warning
    }
    else {
        $c['StatusData'].Text = 'Dane: {0}' -f $location.Root
        $c['StatusData'].SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, 'Mwp.Brush.Text')
        $c['StatusData'].ToolTip = $location.Root
    }
}
