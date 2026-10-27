function Initialize-MwpDashboardView {
    <#
    .SYNOPSIS
        Podpina widok Pulpitu: Dashboard z widgetami (FAZA 5), dodawanie komputera i lista instancji.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '',
        Justification = 'Parametry obsługi zdarzeń WPF są używane w zagnieżdżonych blokach (Invoke-MwpUiSafe -Action), czego reguła nie widzi.')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $View
    )

    $ui = $script:MwpUi
    if ($null -eq $ui.Dashboard) {
        Initialize-MwpUiDashboard
    }
    $v = $View.Controls
    $v['AutoRefreshCheck'].IsChecked = $ui.Dashboard.AutoRefresh
    $v['AutoRefreshCheck'].Add_Click({
            param($control)
            Invoke-MwpUiSafe -Name 'UI.Dashboard.AutoRefresh' -Action {
                $script:MwpUi.Dashboard.AutoRefresh = [bool]$control.IsChecked
                Save-MwpUiDashboard -AutoRefresh
            }
        })
    $v['RefreshAllButton'].Add_Click({
            Invoke-MwpUiSafe -Name 'UI.Dashboard.RefreshAll' -Action {
                foreach ($widget in @($script:MwpUi.Dashboard.Widgets)) {
                    $widget.Pending = $true
                }
                Invoke-MwpUiDashboardTick
            }
        })
    $v['AddWidgetButton'].Add_Click({
            param($control)
            Invoke-MwpUiSafe -Name 'UI.Dashboard.AddWidget' -Action { Edit-MwpUiWidget -Owner (Get-MwpOwnerWindow -Element $control) }
        })
    $v['AddTargetButton'].Add_Click({
            param($control)
            Invoke-MwpUiSafe -Name 'UI.Target.Add' -Action { Edit-MwpUiTarget -Owner (Get-MwpOwnerWindow -Element $control) }
        })
    $v['DashboardBannerClose'].Add_Click({
            $script:MwpUi.Dashboard.Banner = $null
            Update-MwpDashboardWidgets -Force
        })

    $handler = [System.Windows.RoutedEventHandler] {
        param($control, $eventData)
        $button = $eventData.OriginalSource
        if ($button -isnot [System.Windows.Controls.Button]) {
            return
        }
        Invoke-MwpUiSafe -Name ('UI.Widget.{0}' -f $button.Uid) -Action {
            $id = [string]$button.Tag
            $owner = Get-MwpOwnerWindow -Element $button
            switch ($button.Uid) {
                'Refresh' {
                    $widget = @($script:MwpUi.Dashboard.Widgets | Where-Object { $_.Id -eq $id }) | Select-Object -First 1
                    if ($null -ne $widget) {
                        $widget.Pending = $true
                        Invoke-MwpUiDashboardTick
                    }
                }
                'Edit' { Edit-MwpUiWidget -Id $id -Owner $owner }
                'Remove' { Remove-MwpUiWidget -Id $id }
                'MoveLeft' { Move-MwpUiWidget -Id $id -Offset -1 }
                'MoveRight' { Move-MwpUiWidget -Id $id -Offset 1 }
                'Connect' { Connect-MwpUiWidget -Id $id -Owner $owner }
                'Export' { Export-MwpUiWidget -Id $id -Owner $owner }
            }
        }
    }
    $v['WidgetsList'].AddHandler([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent, $handler)
    Register-MwpUiInstanceListHandler -List $v['InstancesList']
}
