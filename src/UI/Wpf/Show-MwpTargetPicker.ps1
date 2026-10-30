function Show-MwpTargetPicker {
    <#
    .SYNOPSIS
        Okno wyboru komputera docelowego i miejsca prezentacji dla nowej instancji modułu.

    .DESCRIPTION
        Wspólny komponent hosta (D-019): lista komputerów z rejestru (Get-MwpTarget), z komputerami
        niedostępnymi dla modułu wyłączonymi i opisanymi (Test-MwpInstanceTarget, np. brak
        RemoteTarget). Tryby zgodne z kontraktem (Test-MwpPresentationMode). Zwraca obiekt
        z ComputerName, Mode (Embedded, SeparateWindow) i Connect albo $null (anulowano).

    .PARAMETER Definition
        Definicja modułu.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [object] $Definition,

        [AllowNull()]
        [object] $Owner
    )

    $dialog = Import-MwpXaml -Path (Join-Path -Path $script:MwpUi.UiRoot -ChildPath 'Dialogs\TargetPicker.xaml')
    $window = $dialog.Root
    $c = $dialog.Controls
    if ($null -eq $Owner) {
        $Owner = $script:MwpUi.Window
    }
    if ($null -ne $Owner -and $Owner.IsVisible) {
        $window.Owner = $Owner
    }
    $c['ModuleText'].Text = 'Moduł: {0} ({1}, wersja {2}). Instancja dostaje własny kontekst wykonania dla wybranego komputera.' -f
    $Definition.Name, $Definition.ModuleName, $Definition.Version

    $rows = @(foreach ($target in @(Get-MwpTarget)) {
            $check = Test-MwpInstanceTarget -Definition $Definition -Target $target
            $detail = if ($target.IsLocal) { 'Komputer lokalny, bez połączenia zdalnego' } else {
                'WinRM {0}, port {1}, uwierzytelnienie: {2}{3}{4}' -f $(if ($target.UseSsl) { 'HTTPS' } else { 'HTTP' }), $target.Port, $target.Authentication,
                $(if ($target.UserName) { ', konto: ' + $target.UserName } else { '' }),
                $(if ([string]$target.ConnectionAddress -ne [string]$target.Name) { ', adres: ' + $target.ConnectionAddress } else { '' })
            }
            if (-not $check.Allowed) {
                $detail = '{0} — {1}' -f $detail, $check.Reason
            }
            [pscustomobject]@{
                Title   = $(if ($target.DisplayName -like ('*{0}*' -f $target.Name)) { $target.DisplayName } else { '{0} ({1})' -f $target.DisplayName, $target.Name })
                Detail  = $detail
                Allowed = $check.Allowed
                Target  = $target
            }
        })
    $c['TargetList'].ItemsSource = $rows
    $first = @($rows | Where-Object { $_.Allowed }) | Select-Object -First 1
    if ($null -ne $first) {
        $c['TargetList'].SelectedItem = $first
    }

    $embedded = Test-MwpPresentationMode -Definition $Definition -Mode Embedded
    $separate = Test-MwpPresentationMode -Definition $Definition -Mode SeparateWindow
    $c['ModeEmbedded'].IsEnabled = $embedded
    $c['ModeSeparate'].IsEnabled = $separate
    if (-not $embedded) {
        $c['ModeSeparate'].IsChecked = $true
    }

    $state = @{ Result = $null }
    $c['OkButton'].Add_Click({
            $selected = $c['TargetList'].SelectedItem
            if ($null -eq $selected -or -not $selected.Allowed) {
                return
            }
            $state.Result = [pscustomobject]@{
                ComputerName = $selected.Target.Name
                Target       = $selected.Target
                Mode         = $(if ($c['ModeSeparate'].IsChecked) { 'SeparateWindow' } else { 'Embedded' })
                Connect      = [bool]$c['ConnectCheck'].IsChecked
            }
            $window.Close()
        })
    $c['TargetList'].Add_MouseDoubleClick({
            $c['OkButton'].RaiseEvent((New-Object -TypeName System.Windows.RoutedEventArgs -ArgumentList ([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent)))
        })
    $c['CancelButton'].Add_Click({ $window.Close() })

    $null = $window.ShowDialog()
    $state.Result
}
