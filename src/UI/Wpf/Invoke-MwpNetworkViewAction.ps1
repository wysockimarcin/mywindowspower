function Invoke-MwpNetworkViewAction {
    <#
    .SYNOPSIS
        Obsługa przycisków widoku sieci: odczyt, zatwierdzenie zmiany, włącz/wyłącz adapter, DHCP, DNS, flush DNS, testy, resety i cofnięcie.

    .DESCRIPTION
        Zmiany idą przez Invoke-MwpUiInstanceChange z krokami — funkcjami MWP.Network z kontekstem
        instancji (podgląd -WhatIf w tle, okno potwierdzenia z komputerem docelowym, wykonanie w tle,
        ponowny odczyt). Wyłączenie adaptera, którym idzie połączenie aplikacji, i resety to operacje
        destrukcyjne z wpisaniem nazwy komputera (D-049); wyłączenie adaptera połączenia przekazuje
        -AllowConnectionAdapter dopiero po tym dodatkowym potwierdzeniu. DNS i wyłączenie dostają czas
        na zatwierdzenie z listy (domyślnie 120 s).

    .PARAMETER Action
        Nazwa przycisku (x:Name) z Views\Network.xaml.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Zmiany przechodzą przez podgląd i okno potwierdzenia (Invoke-MwpUiInstanceChange).')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable] $Entry,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Action,

        [AllowNull()]
        [object] $Owner
    )

    $p = $Entry.ModuleView.Controls
    $view = $Entry.Network
    $context = $Entry.Instance.Context
    $computerName = $context.ComputerName
    $after = 'Start-MwpUiNetworkRefresh'
    $row = $p['NetworkAdaptersGrid'].SelectedItem
    $adapter = if ($null -ne $row -and $null -ne $view.Status) { @($view.Status.Adapters | Where-Object { $_.InterfaceIndex -eq [int]$row.InterfaceIndex }) | Select-Object -First 1 } else { $null }
    $identity = if ($null -ne $adapter) { @{ InterfaceIndex = $adapter.InterfaceIndex; InterfaceGuid = $adapter.InterfaceGuid } } else { $null }
    $rollback = $p['NetworkRollbackBox'].SelectedItem
    $rollbackSeconds = if ($null -ne $rollback) { [int]$rollback.Value } else { 120 }
    $needsAdapter = 'NetworkEnableButton', 'NetworkDisableButton', 'NetworkRenewButton', 'NetworkDnsButton'
    if ($needsAdapter -contains $Action -and $null -eq $adapter) {
        Show-MwpMessage -Text 'Wybierz adapter z listy.' -Owner $Owner
        return
    }

    switch ($Action) {
        'NetworkRefreshButton' {
            Start-MwpUiNetworkRefresh -Entry $Entry
        }
        'NetworkApproveButton' {
            $pending = $p['NetworkPendingGrid'].SelectedItem
            if ($null -eq $pending) { return }
            Invoke-MwpUiInstanceChange -Entry $Entry -Header 'Zatwierdzenie zmiany sieci' -Target $pending.Description -ConfirmText 'Zatwierdź' -AfterCommand $after -Owner $Owner `
                -Steps @(@{ Command = 'Approve-MwpNetworkChange'; Parameters = @{ ChangeId = [string]$pending.ChangeId }; Label = 'Zatwierdzenie' })
        }
        'NetworkEnableButton' {
            Invoke-MwpUiInstanceChange -Entry $Entry -Header 'Włączenie adaptera sieciowego' -Target $adapter.Name -AfterCommand $after -Owner $Owner `
                -Steps @(@{ Command = 'Enable-MwpNetAdapter'; Parameters = $identity; Label = ('Włączenie: {0}' -f $adapter.Name) })
        }
        'NetworkDisableButton' {
            $parameters = $identity.Clone()
            $parameters['RollbackSeconds'] = $rollbackSeconds
            if ($adapter.IsConnectionAdapter) {
                # Dodatkowe potwierdzenie: adapter połączenia — operacja destrukcyjna z wpisaniem nazwy komputera.
                $parameters['AllowConnectionAdapter'] = $true
                Invoke-MwpUiInstanceChange -Entry $Entry -Header 'Wyłączenie adaptera połączenia' -Class Destructive -RequireText $computerName -ConfirmText 'Wyłącz' `
                    -Target ("{0} — tym adapterem idzie połączenie z komputerem {1}; zostanie przerwane i wróci po automatycznym włączeniu ({2} s)." -f $adapter.Name, $computerName, $rollbackSeconds) `
                    -AfterCommand $after -Owner $Owner -Steps @(@{ Command = 'Disable-MwpNetAdapter'; Parameters = $parameters; Label = ('Wyłączenie: {0}' -f $adapter.Name) })
                return
            }
            Invoke-MwpUiInstanceChange -Entry $Entry -Header 'Wyłączenie adaptera sieciowego' -ConfirmText 'Wyłącz' -Target $adapter.Name -AfterCommand $after -Owner $Owner `
                -Steps @(@{ Command = 'Disable-MwpNetAdapter'; Parameters = $parameters; Label = ('Wyłączenie: {0}' -f $adapter.Name) })
        }
        'NetworkRenewButton' {
            Invoke-MwpUiInstanceChange -Entry $Entry -Header 'Odnowienie dzierżawy DHCP' -Target $adapter.Name -AfterCommand $after -Owner $Owner `
                -Steps @(@{ Command = 'Update-MwpDhcpLease'; Parameters = $identity; Label = ('DHCP: {0}' -f $adapter.Name) })
        }
        'NetworkDnsButton' {
            $preset = $p['NetworkDnsPresetBox'].SelectedItem
            if ($null -eq $preset) { return }
            $parameters = $identity.Clone()
            $parameters['RollbackSeconds'] = $rollbackSeconds
            if ($preset.Value -eq 'Custom') {
                $addresses = @(([string]$p['NetworkDnsCustomBox'].Text) -split '[\s,;]+' | Where-Object { $_ })
                if ($addresses.Count -eq 0 -or $addresses.Count -gt 8) {
                    Show-MwpMessage -Text 'Wpisz od 1 do 8 adresów serwerów DNS (IPv4 lub IPv6), oddzielonych przecinkiem lub spacją.' -Kind Warning -Owner $Owner
                    return
                }
                $parameters['ServerAddress'] = [string[]]$addresses
            }
            else {
                $parameters['Preset'] = [string]$preset.Value
            }
            Invoke-MwpUiInstanceChange -Entry $Entry -Header 'Zmiana serwerów DNS' -Target ('{0}: {1}' -f $adapter.Name, $preset.Label) -AfterCommand $after -Owner $Owner `
                -Steps @(@{ Command = 'Set-MwpDnsServer'; Parameters = $parameters; Label = ('DNS: {0}' -f $adapter.Name) })
        }
        'NetworkFlushButton' {
            Invoke-MwpUiInstanceChange -Entry $Entry -Header 'Opróżnienie pamięci DNS' -Target 'Pamięć podręczna klienta DNS' -AfterCommand $after -Owner $Owner `
                -Steps @(@{ Command = 'Clear-MwpDnsCache'; Parameters = @{}; Label = 'Flush DNS' })
        }
        'NetworkTestButton' {
            $port = 0
            $portText = ([string]$p['NetworkTestPortBox'].Text).Trim()
            if ($portText -and (-not [int]::TryParse($portText, [ref]$port) -or $port -lt 1 -or $port -gt 65535)) {
                Show-MwpMessage -Text 'Port musi być liczbą od 1 do 65535.' -Kind Warning -Owner $Owner
                return
            }
            Start-MwpUiNetworkRefresh -Entry $Entry -Kind Test -TestParameters @{
                ExternalHost = ([string]$p['NetworkTestHostBox'].Text).Trim()
                DnsName      = ([string]$p['NetworkTestDnsBox'].Text).Trim()
                PortHost     = ([string]$p['NetworkTestPortHostBox'].Text).Trim()
                Port         = $port
            }
        }
        'NetworkWinsockButton' {
            Invoke-MwpUiInstanceChange -Entry $Entry -Header 'Reset katalogu Winsock' -Class Destructive -RequireText $computerName -ConfirmText 'Resetuj' `
                -Target 'netsh winsock reset — wymaga ponownego uruchomienia komputera, nie można cofnąć' -AfterCommand $after -Owner $Owner `
                -Steps @(@{ Command = 'Reset-MwpNetworkStack'; Parameters = @{ Component = 'Winsock' }; Label = 'Reset Winsock' })
        }
        'NetworkIpResetButton' {
            Invoke-MwpUiInstanceChange -Entry $Entry -Header 'Reset stosu TCP/IP' -Class Destructive -RequireText $computerName -ConfirmText 'Resetuj' `
                -Target 'netsh int ip reset — usuwa statyczne IP i DNS, wymaga ponownego uruchomienia komputera, nie można cofnąć' -AfterCommand $after -Owner $Owner `
                -Steps @(@{ Command = 'Reset-MwpNetworkStack'; Parameters = @{ Component = 'IP' }; Label = 'Reset stosu IP' })
        }
        'NetworkUndoButton' {
            $undo = $p['NetworkUndoGrid'].SelectedItem
            if ($null -eq $undo) { return }
            Invoke-MwpUiInstanceChange -Entry $Entry -Header 'Cofnięcie zmiany sieci' -Target $undo.Description -AfterCommand $after -Owner $Owner `
                -Steps @(@{ Command = 'Invoke-MwpUndo'; Parameters = @{ Id = $undo.Id }; Label = 'Cofnięcie' })
        }
    }
}
