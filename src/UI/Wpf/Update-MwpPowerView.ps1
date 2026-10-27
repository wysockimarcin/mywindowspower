function Update-MwpPowerView {
    <#
    .SYNOPSIS
        Odświeża widok Zasilanie z odczytanego stanu: plany, listy AC/DC, hibernacja, cofnięcia, dostępność przycisków.

    .DESCRIPTION
        Listy rozwijane i pola wyboru są wypełniane ze stanu tylko po nowym odczycie albo z -Reset,
        żeby odświeżenie widoku nie kasowało wyborów użytkownika przed „Zastosuj zmiany”.
        Z -StateOnly (zegar okna) zmienia tylko dostępność przycisków.

    .PARAMETER Reset
        Przywraca wybory do odczytanego stanu.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Zmienia tylko kontrolki okna.')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable] $Entry,

        [switch] $StateOnly,

        [switch] $Reset
    )

    $p = $Entry.ModuleView.Controls
    $power = $Entry.Power
    $status = $power.Status
    $context = $Entry.Instance.Context
    $busy = $Entry.Busy -gt 0 -or $power.Loading
    $connected = -not (Get-MwpConnectionStateInfo -Context $context).NeedsCredential
    $ready = $connected -and -not $busy -and $null -ne $status
    $selected = $p['PlansGrid'].SelectedItem

    $p['PowerRefreshButton'].IsEnabled = $connected -and -not $busy
    foreach ($name in 'ActivatePlanButton', 'CopyPlanButton', 'RenamePlanButton') {
        $p[$name].IsEnabled = $ready -and $null -ne $selected
    }
    $p['RemovePlanButton'].IsEnabled = $ready -and $null -ne $selected -and -not $selected.IsActive -and -not $selected.IsBuiltIn
    $p['UltimatePlanButton'].IsEnabled = $ready
    $p['ApplySettingsButton'].IsEnabled = $ready
    $p['ResetSettingsButton'].IsEnabled = $null -ne $status
    $p['UndoButton'].IsEnabled = $connected -and -not $busy -and $null -ne $p['UndoGrid'].SelectedItem
    $p['BatteryReportButton'].IsEnabled = $connected -and -not $power.Reporting
    $p['EnergyReportButton'].IsEnabled = $connected -and -not $power.Reporting -and ($null -eq $status -or $false -ne $status.IsAdministrator)
    $p['OpenReportButton'].IsEnabled = [bool]$power.LastReport
    if ($StateOnly) {
        return
    }

    # Nagłówek i ostrzeżenia.
    $p['PowerStatusText'].Text = if ($power.Loading) {
        'Odczyt stanu zasilania komputera {0}…' -f $context.ComputerName
    }
    elseif ($null -ne $status) {
        'Komputer {0} · plan aktywny: {1} · odczyt {2}' -f $context.ComputerName, $(if ($null -ne $status.ActivePlan) { $status.ActivePlan.Name } else { '(brak)' }),
        $(try { ([datetime]$status.CollectedAt).ToString('HH:mm:ss') } catch { $status.CollectedAt })
    }
    else {
        'Brak odczytu stanu zasilania.'
    }
    $warnings = New-Object -TypeName System.Collections.Generic.List[string]
    if ($power.Error) {
        $warnings.Add($power.Error)
    }
    if ($null -ne $status) {
        foreach ($warning in @($status.Warnings)) {
            $warnings.Add([string]$warning)
        }
        if ($false -eq $status.IsAdministrator) {
            $warnings.Add('Brak uprawnień administratora na tym komputerze: hibernacja, szybkie uruchamianie i raport energii są niedostępne (uruchom aplikację jako administrator albo połącz się kontem administratora).')
        }
    }
    $p['PowerWarningText'].Text = $warnings -join [Environment]::NewLine
    $p['PowerWarningBanner'].Visibility = $(if ($warnings.Count -gt 0) { 'Visible' } else { 'Collapsed' })

    # Cofnięcia zmian zasilania tego komputera (rejestr cofnięć, D-028).
    $undoRows = @(Get-MwpUndoEntry -ComputerName $context.ComputerName -Status Pending | Where-Object { $_.Module -eq 'MWP.Power' } |
            Sort-Object -Property CreatedAt -Descending | Select-Object -First 50 | ForEach-Object {
                [pscustomobject]@{ Id = $_.Id; When = $(if ($_.CreatedAt) { ([datetime]$_.CreatedAt).ToString('yyyy-MM-dd HH:mm') } else { '' }); Description = $_.Description }
            })
    $p['UndoGrid'].ItemsSource = $undoRows

    if ($null -eq $status) {
        return
    }

    # Plany (zaznaczenie zostaje po odświeżeniu).
    $selectedGuid = if ($null -ne $selected) { $selected.Guid } else { $null }
    $rows = @(foreach ($plan in @($status.Plans)) {
            [pscustomobject]@{
                Guid      = $plan.Guid
                Name      = $plan.Name
                State     = $(if ($plan.IsActive) { 'Aktywny' } else { '' })
                Kind      = $(if ($plan.IsBuiltIn) { 'Wbudowany' } else { 'Własny' })
                IsActive  = [bool]$plan.IsActive
                IsBuiltIn = [bool]$plan.IsBuiltIn
            }
        })
    $p['PlansGrid'].ItemsSource = $rows
    if ($selectedGuid) {
        $p['PlansGrid'].SelectedItem = @($rows | Where-Object { $_.Guid -eq $selectedGuid }) | Select-Object -First 1
    }

    # Listy AC/DC i pola wyboru — tylko po nowym odczycie albo na żądanie.
    if ($Reset -or -not [object]::ReferenceEquals($power.FilledFor, $status)) {
        $hasBattery = $false -ne $status.HasBattery
        foreach ($setting in @($status.Settings)) {
            $visible = $(if ($setting.Available) { 'Visible' } else { 'Collapsed' })
            $p[$setting.Id + 'Label'].Visibility = $visible
            foreach ($source in 'Ac', 'Dc') {
                $combo = $p[$setting.Id + $source]
                $current = $setting.$source
                $options = @(Get-MwpPowerOption -Kind $setting.Kind -Current $current -MaxIndex $(if ($setting.Kind -eq 'Action') { $setting.MaxIndex } else { 4 }))
                $combo.ItemsSource = $options
                $combo.SelectedItem = @($options | Where-Object { $null -ne $current -and $_.Value -eq [long]$current }) | Select-Object -First 1
                $combo.Visibility = $visible
            }
        }
        $p['BatteryNote'].Visibility = $(if ($hasBattery) { 'Collapsed' } else { 'Visible' })
        $p['HibernateCheck'].IsChecked = $(if ($null -ne $status.Hibernate) { [bool]$status.Hibernate } else { $null })
        $p['FastStartupCheck'].IsChecked = $(if ($null -ne $status.FastStartup) { [bool]$status.FastStartup } else { $true })
        $power.FilledFor = $status
    }
    $admin = $false -ne $status.IsAdministrator
    $p['HibernateCheck'].IsEnabled = $admin
    $p['FastStartupCheck'].IsEnabled = $admin
}
