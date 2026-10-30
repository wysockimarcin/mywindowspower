function Update-MwpServicesView {
    <#
    .SYNOPSIS
        Odświeża widok Usługi: nagłówek i ostrzeżenia, lista z filtrami, szczegóły wybranej usługi, profil, cofnięcia, dostępność przycisków.

    .DESCRIPTION
        Z -StateOnly (zegar okna, zmiana wyboru na listach) zmienia tylko dostępność przycisków.
        Z -Filter przelicza tylko listę usług (filtry, bez ponownego odczytu), z -Selection — panel
        szczegółów wybranej usługi. Zaznaczenie usługi zostaje po odświeżeniu (po nazwie). Blokada
        usług chronionych: Get-MwpServiceActionState i Get-MwpServiceViewOption (D-045).

    .PARAMETER StateOnly
        Tylko przyciski.

    .PARAMETER Filter
        Lista usług po zmianie filtrów.

    .PARAMETER Selection
        Szczegóły po zmianie wybranej usługi.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Zmienia tylko kontrolki okna.')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable] $Entry,

        [switch] $StateOnly,

        [switch] $Filter,

        [switch] $Selection
    )

    $p = $Entry.ModuleView.Controls
    $view = $Entry.Services
    $list = $view.List
    $context = $Entry.Instance.Context
    $busy = $Entry.Busy -gt 0 -or $view.Loading
    $connected = -not (Get-MwpConnectionStateInfo -Context $context).NeedsCredential
    $ready = $connected -and -not $busy -and $null -ne $list

    $row = $p['ServicesGrid'].SelectedItem
    $service = if ($null -ne $row -and $view.ByName.ContainsKey([string]$row.Name)) { $view.ByName[[string]$row.Name] } else { $null }

    if ($Filter -or (-not $StateOnly -and -not $Selection)) {
        $p['ServicesStatusText'].Text = if ($view.Loading) {
            'Odczyt usług komputera {0}…' -f (Format-MwpTargetLabel -Context $context)
        }
        elseif ($null -ne $list) {
            'Komputer {0} · {1} usług · odczyt {2}' -f (Format-MwpTargetLabel -Context $context), @($list.Services).Count, $(try { ([datetime]$list.CollectedAt).ToString('HH:mm:ss') } catch { $list.CollectedAt })
        }
        else {
            'Brak odczytu usług.'
        }
        if ($null -ne $list) {
            $status = $p['ServiceStatusFilter'].SelectedItem
            $type = $p['ServiceTypeFilter'].SelectedItem
            $selectedName = if ($null -ne $row) { [string]$row.Name } else { $null }
            $lock = [string][char]0xE72E   # kłódka w czcionce ikon (Mwp.Font.Icons)
            $rows = @(Select-MwpService -Service @($list.Services) -Status $(if ($null -ne $status) { $status.Value } else { 'All' }) `
                    -StartupType $(if ($null -ne $type) { $type.Value } else { 'All' }) -Search $p['ServiceSearchBox'].Text -ProtectedOnly:([bool]$p['ServiceProtectedFilter'].IsChecked) | ForEach-Object {
                    [pscustomobject]@{
                        Lock            = $(if ($_.IsProtected) { $lock } else { '' })
                        Name            = $_.Name
                        DisplayName     = $_.DisplayName
                        StatusText      = $_.StatusText
                        StartupTypeText = $_.StartupTypeText
                        Account         = $_.Account
                    }
                })
            $p['ServicesGrid'].ItemsSource = $rows
            $p['ServiceCountText'].Text = 'Pokazano {0} z {1}' -f $rows.Count, @($list.Services).Count
            if ($selectedName) {
                $p['ServicesGrid'].SelectedItem = @($rows | Where-Object { $_.Name -eq $selectedName }) | Select-Object -First 1
            }
            $row = $p['ServicesGrid'].SelectedItem
            $service = if ($null -ne $row -and $view.ByName.ContainsKey([string]$row.Name)) { $view.ByName[[string]$row.Name] } else { $null }
        }
        $Selection = $true
    }

    if (-not $StateOnly -and -not $Filter -and -not $Selection) {
        return
    }
    if ($Selection) {
        $detail = Get-MwpServiceDetail -Service $service -HasGraph ($null -ne $list -and [bool]$list.HasGraph)
        $p['ServiceDetailTitle'].Text = $detail.Title
        $p['ServiceDetailText'].Text = $detail.Text
        $options = @(Get-MwpServiceViewOption -Kind StartupType -Service $service)
        $p['StartupTypeBox'].ItemsSource = $options
        $p['StartupTypeBox'].SelectedItem = $(if ($null -ne $service) { @($options | Where-Object { $_.Value -eq $service.StartupType }) | Select-Object -First 1 } else { $null })
    }

    if (-not $StateOnly) {
        # Ostrzeżenia, profil i cofnięcia (poza zegarem okna).
        $warnings = New-Object -TypeName System.Collections.Generic.List[string]
        if ($view.Error) {
            $warnings.Add($view.Error)
        }
        if ($null -ne $list) {
            foreach ($warning in @($list.Warnings)) {
                $warnings.Add([string]$warning)
            }
            if ($false -eq $list.IsAdministrator) {
                $warnings.Add('Brak uprawnień administratora na tym komputerze: uruchamianie, zatrzymywanie i zmiana typu uruchomienia są niedostępne (uruchom aplikację jako administrator albo połącz się kontem administratora).')
            }
        }
        $p['ServicesWarningText'].Text = $warnings -join [Environment]::NewLine
        $p['ServicesWarningBanner'].Visibility = $(if ($warnings.Count -gt 0) { 'Visible' } else { 'Collapsed' })
        $p['ProfileGrid'].ItemsSource = @($view.Diff)
        $undoRows = @(Get-MwpUndoEntry -ComputerName $context.ComputerName -Status Pending | Where-Object { $_.Module -eq 'MWP.Services' } |
                Sort-Object -Property CreatedAt -Descending | Select-Object -First 50 | ForEach-Object {
                    [pscustomobject]@{ Id = $_.Id; When = $(if ($_.CreatedAt) { ([datetime]$_.CreatedAt).ToString('yyyy-MM-dd HH:mm') } else { '' }); Description = $_.Description }
                })
        $p['ServicesUndoGrid'].ItemsSource = $undoRows
    }

    # Przyciski.
    $administrator = $null -eq $list -or $false -ne $list.IsAdministrator
    $wanted = $p['StartupTypeBox'].SelectedItem
    $actions = Get-MwpServiceActionState -Service $service -Ready ($ready -and $administrator) -StartupType $(if ($null -ne $wanted) { $wanted.Value } else { '' })
    $p['StartServiceButton'].IsEnabled = $actions.CanStart
    $p['StopServiceButton'].IsEnabled = $actions.CanStop
    $p['RestartServiceButton'].IsEnabled = $actions.CanRestart
    $p['SetStartupTypeButton'].IsEnabled = $actions.CanSetStartupType
    $p['StartupTypeBox'].IsEnabled = $null -ne $service -and $service.StartupType -ne 'Unknown'
    $p['ServiceProtectedText'].Text = [string]$actions.ProtectionText
    $p['ServiceProtectedBanner'].Visibility = $(if ($actions.ProtectionText) { 'Visible' } else { 'Collapsed' })
    $p['ServicesRefreshButton'].IsEnabled = $connected -and -not $busy
    $p['ExportProfileButton'].IsEnabled = $null -ne $list
    $p['LoadProfileButton'].IsEnabled = $null -ne $list -and -not $busy
    $changes = @($view.Diff | Where-Object { $_.Action -eq 'Change' })
    $selectedChanges = @($p['ProfileGrid'].SelectedItems | Where-Object { $_.Action -eq 'Change' })
    $p['ApplyProfileButton'].IsEnabled = $ready -and $administrator -and $changes.Count -gt 0
    $p['ApplySelectedProfileButton'].IsEnabled = $ready -and $administrator -and $selectedChanges.Count -gt 0
    $p['ServicesUndoButton'].IsEnabled = $connected -and -not $busy -and $null -ne $p['ServicesUndoGrid'].SelectedItem
}
