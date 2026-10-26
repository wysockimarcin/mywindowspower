function Switch-MwpLogPanel {
    <#
    .SYNOPSIS
        Pokazuje albo ukrywa panel logu (Dziennik operacji) pod widokiem.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [bool] $Visible
    )

    $ui = $script:MwpUi
    $c = $ui.Controls
    $ui.LogVisible = $Visible
    if ($Visible) {
        $c['LogRow'].Height = New-Object -TypeName System.Windows.GridLength -ArgumentList 220
        $c['LogSplitter'].Visibility = 'Visible'
        Update-MwpLogPanel
    }
    else {
        $c['LogRow'].Height = New-Object -TypeName System.Windows.GridLength -ArgumentList 0
        $c['LogSplitter'].Visibility = 'Collapsed'
    }
}
