function Update-MwpInstanceView {
    <#
    .SYNOPSIS
        Odświeża widok instancji: tytuł, stan połączenia (plakietka i błąd), dostępność przycisków.

    .DESCRIPTION
        Stan połączenia pochodzi wyłącznie z kontekstu tej instancji (Context.Connection); błąd
        połączenia jest pokazany w widoku instancji, nie jako błąd aplikacji (D-019).

    .PARAMETER StateOnly
        Tylko plakietka, komunikat błędu i przyciski (wywołanie z zegara okna).
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Zmienia tylko kontrolki okna.')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable] $Entry,

        [switch] $StateOnly
    )

    $v = $Entry.View.Controls
    $instance = $Entry.Instance
    $context = $instance.Context
    $state = Get-MwpConnectionStateInfo -Context $context

    if (-not $StateOnly) {
        $v['InstanceTitle'].Text = $instance.Name
        $v['InstanceSubtitle'].Text = 'Moduł {0} {1} · komputer {2} ({3}) · {4}' -f $instance.ModuleName, $instance.ModuleVersion, $context.ComputerName,
        $(if ($context.Mode -eq 'Local') { 'lokalnie' } else { 'zdalnie, WinRM' }),
        $(if ($Entry.Placement -eq 'SeparateWindow') { 'w osobnym oknie' } else { 'w oknie głównym' })
        $v['DetachButton'].Content = $(if ($Entry.Placement -eq 'SeparateWindow') { 'Do okna głównego' } else { 'W osobnym oknie' })
        $v['DetachButton'].IsEnabled = Test-MwpPresentationMode -Definition $Entry.Definition -Mode $(if ($Entry.Placement -eq 'SeparateWindow') { 'Embedded' } else { 'SeparateWindow' })
        if ($v['NoteBox'].Text -ne [string]$instance.State['Note']) {
            $v['NoteBox'].Text = [string]$instance.State['Note']
        }
        if ($null -ne $Entry.Window) {
            $Entry.Window.Title = '{0} — My Windows Power' -f $instance.Name
        }
    }

    $v['StateBadge'].DataContext = $state
    $busy = $Entry.Busy -gt 0
    $remote = $state.IsRemote
    $v['ConnectButton'].Visibility = $(if ($remote) { 'Visible' } else { 'Collapsed' })
    $v['DisconnectButton'].Visibility = $(if ($remote) { 'Visible' } else { 'Collapsed' })
    $v['ConnectButton'].IsEnabled = $remote -and -not $busy -and $state.State -notin @('Connected', 'Connecting')
    $v['DisconnectButton'].IsEnabled = $remote -and -not $busy -and $state.State -eq 'Connected'
    $v['TestButton'].IsEnabled = -not $busy
    $v['ProbeButton'].IsEnabled = -not $busy

    if ($null -ne $Entry['ViewInfo'] -and $null -ne $Entry['ModuleView']) {
        & $Entry.ViewInfo.Update -Entry $Entry -StateOnly:$StateOnly
    }

    $message = $Entry.Message
    if ($state.Detail) {
        $message = $(if ($message) { '{0} {1}' -f $message, $state.Detail } else { $state.Detail })
    }
    if ($message) {
        $v['ErrorText'].Text = $message
        $v['ErrorBanner'].Visibility = 'Visible'
    }
    else {
        $v['ErrorBanner'].Visibility = 'Collapsed'
    }
}
