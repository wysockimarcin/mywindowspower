function Update-MwpDashboardView {
    <#
    .SYNOPSIS
        Odświeża Pulpit: kafelki widgetów (gdy zmienił się ich stan), komputery docelowe (z liczbą instancji) i otwarte instancje.
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
    $targets = @(Get-MwpTarget)
    $entries = @($ui.Instances.Values)
    $v['TargetsList'].ItemsSource = @(foreach ($target in $targets) {
            $own = @($entries | Where-Object { $_.Instance.Context.ComputerName -eq $target.Name })
            $connected = @($own | Where-Object { $_.Instance.Context.Connection.State -eq 'Connected' }).Count
            [pscustomobject]@{
                # D-054: karta pokazuje nazwę komputera (localhost — nazwę hosta), a adres połączenia tylko w opisie połączenia.
                Name        = Format-MwpTargetLabel -ComputerName $(if ($target.IsLocal) { 'localhost' } else { $target.Name })
                DisplayName = $target.DisplayName
                Connection  = $(if ($target.IsLocal) { 'Komputer lokalny · bez połączenia zdalnego' } else {
                        'WinRM {0}, port {1} · {2}{3}' -f $(if ($target.UseSsl) { 'HTTPS' } else { 'HTTP' }), $target.Port, $target.Authentication,
                        $(if ([string]$target.ConnectionAddress -ne [string]$target.Name) { ' · adres {0}' -f $target.ConnectionAddress } else { '' })
                    })
                Instances   = 'Otwarte instancje: {0}{1}' -f $own.Count, $(if (-not $target.IsLocal -and $own.Count -gt 0) { ' (połączone: {0})' -f $connected } else { '' })
            }
        })
    $rows = @(Get-MwpUiInstanceRow)
    $v['InstancesList'].ItemsSource = $rows
    $v['NoInstancesText'].Visibility = $(if ($rows.Count -eq 0) { 'Visible' } else { 'Collapsed' })
    $widgets = @()
    if ($null -ne $ui.Dashboard) {
        $widgets = @($ui.Dashboard.Widgets | Where-Object { -not $_.Removed })
    }
    $v['Summary'].Text = 'Widgety: {0} · komputery: {1} · otwarte instancje: {2}' -f $widgets.Count, $targets.Count, $rows.Count
    Update-MwpDashboardWidgets
}
