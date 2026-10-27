function Update-MwpDashboardWidgets {
    <#
    .SYNOPSIS
        Odświeża kafelki widgetów na Pulpicie, gdy zmienił się stan któregoś widgetu.

    .DESCRIPTION
        Wiersze buduje Get-MwpWidgetRow (bez WPF). Lista kafelków jest podmieniana tylko wtedy, gdy
        zmienił się podpis Dashboardu (identyfikatory i wersje widgetów, baner), żeby zegar okna nie
        przebudowywał kontrolek co 250 ms. Działa tylko, gdy widok Pulpitu istnieje.

    .PARAMETER Force
        Przebudowa bez sprawdzania podpisu.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '',
        Justification = 'Odświeża wszystkie kafelki widgetów Pulpitu.')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Zmienia tylko kontrolki okna.')]
    [CmdletBinding()]
    param(
        [switch] $Force
    )

    $ui = $script:MwpUi
    $view = $ui.Views['dashboard']
    $dashboard = $ui.Dashboard
    if ($null -eq $view -or $null -eq $dashboard) {
        return
    }
    $widgets = @($dashboard.Widgets | Where-Object { -not $_.Removed })
    $signature = '{0}|{1}' -f (@($widgets | ForEach-Object { '{0}:{1}' -f $_.Id, $_.Version }) -join ','), $dashboard.Banner
    if (-not $Force -and $signature -eq $dashboard.Signature) {
        return
    }
    $dashboard.Signature = $signature
    $v = $view.Controls
    $v['WidgetsList'].ItemsSource = @(Get-MwpWidgetRow -Widget $widgets)
    $v['NoWidgetsText'].Visibility = $(if ($widgets.Count -eq 0) { 'Visible' } else { 'Collapsed' })
    $v['DashboardBanner'].Visibility = $(if ($dashboard.Banner) { 'Visible' } else { 'Collapsed' })
    $v['DashboardBannerText'].Text = [string]$dashboard.Banner
}
