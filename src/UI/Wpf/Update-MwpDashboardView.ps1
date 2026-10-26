function Update-MwpDashboardView {
    <#
    .SYNOPSIS
        Odświeża Pulpit: komputery docelowe (z liczbą instancji) i otwarte instancje.
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
                Name        = $target.Name
                DisplayName = $target.DisplayName
                Connection  = $(if ($target.IsLocal) { 'Komputer lokalny · bez połączenia zdalnego' } else {
                        'WinRM {0}, port {1} · {2}' -f $(if ($target.UseSsl) { 'HTTPS' } else { 'HTTP' }), $target.Port, $target.Authentication
                    })
                Instances   = 'Otwarte instancje: {0}{1}' -f $own.Count, $(if (-not $target.IsLocal -and $own.Count -gt 0) { ' (połączone: {0})' -f $connected } else { '' })
            }
        })
    $rows = @(Get-MwpUiInstanceRow)
    $v['InstancesList'].ItemsSource = $rows
    $v['NoInstancesText'].Visibility = $(if ($rows.Count -eq 0) { 'Visible' } else { 'Collapsed' })
    $v['Summary'].Text = 'Komputery: {0} · otwarte instancje: {1}' -f $targets.Count, $rows.Count
}
