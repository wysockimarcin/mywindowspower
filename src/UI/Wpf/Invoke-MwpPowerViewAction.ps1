function Invoke-MwpPowerViewAction {
    <#
    .SYNOPSIS
        Obsługa przycisków widoku Zasilanie: odczyt, zmiany planów i ustawień (podgląd, potwierdzenie, wykonanie w tle), raporty, cofnięcie.

    .DESCRIPTION
        Zmiany idą przez Invoke-MwpUiInstanceChange z krokami — funkcjami MWP.Power z kontekstem
        instancji (D-044). Usunięcie planu jest operacją destrukcyjną (wpisanie nazwy planu).
        Cofnięcie wywołuje Invoke-MwpUndo z kontekstem tej instancji.

    .PARAMETER Action
        Nazwa przycisku (x:Name) z Views\Power.xaml.
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
    $plan = $p['PlansGrid'].SelectedItem
    $name = $p['PlanNameBox'].Text.Trim()
    $after = 'Start-MwpUiPowerRefresh'
    $nameError = 'Nazwa planu: do 128 znaków, bez cudzysłowów i znaków sterujących.'
    $validName = { param([string] $Text) $Text.Length -le 128 -and $Text -notmatch '["\p{Cc}]' }

    switch ($Action) {
        'PowerRefreshButton' {
            Start-MwpUiPowerRefresh -Entry $Entry
        }
        'ActivatePlanButton' {
            if ($null -eq $plan) { return }
            Invoke-MwpUiInstanceChange -Entry $Entry -Header 'Aktywacja planu zasilania' -Target ("Plan '{0}'" -f $plan.Name) -AfterCommand $after -Owner $Owner `
                -Steps @(@{ Command = 'Set-MwpActivePowerPlan'; Parameters = @{ Guid = $plan.Guid }; Label = 'Aktywacja planu' })
        }
        'UltimatePlanButton' {
            Invoke-MwpUiInstanceChange -Entry $Entry -Header 'Dodanie planu „Najwyższa wydajność”' -Target 'Kopia ukrytego szablonu Windows (e9a42b02-d5df-448d-aa00-03f14749eb61)' -AfterCommand $after -Owner $Owner `
                -Steps @(@{ Command = 'Add-MwpUltimatePowerPlan'; Parameters = @{}; Label = 'Najwyższa wydajność' })
        }
        'CopyPlanButton' {
            if ($null -eq $plan) { return }
            if ($name -and -not (& $validName $name)) {
                Show-MwpMessage -Text $nameError -Kind Warning -Owner $Owner
                return
            }
            $parameters = @{ Guid = $plan.Guid }
            if ($name) {
                $parameters['Name'] = $name
            }
            Invoke-MwpUiInstanceChange -Entry $Entry -Header 'Duplikowanie planu zasilania' -Target ("Kopia planu '{0}'" -f $plan.Name) -AfterCommand $after -Owner $Owner `
                -Steps @(@{ Command = 'Copy-MwpPowerPlan'; Parameters = $parameters; Label = 'Duplikowanie planu' })
        }
        'RenamePlanButton' {
            if ($null -eq $plan) { return }
            if (-not $name -or -not (& $validName $name)) {
                Show-MwpMessage -Text ('Wpisz nową nazwę w polu „Nazwa”. {0}' -f $nameError) -Kind Warning -Owner $Owner
                return
            }
            Invoke-MwpUiInstanceChange -Entry $Entry -Header 'Zmiana nazwy planu zasilania' -Target ("Plan '{0}'" -f $plan.Name) -AfterCommand $after -Owner $Owner `
                -Steps @(@{ Command = 'Rename-MwpPowerPlan'; Parameters = @{ Guid = $plan.Guid; Name = $name }; Label = 'Zmiana nazwy' })
        }
        'RemovePlanButton' {
            if ($null -eq $plan) { return }
            Invoke-MwpUiInstanceChange -Entry $Entry -Header 'Usunięcie planu zasilania' -Class Destructive -Target ("Plan '{0}' ({1})" -f $plan.Name, $plan.Guid) `
                -RequireText $plan.Name -AfterCommand $after -Owner $Owner `
                -Steps @(@{ Command = 'Remove-MwpPowerPlan'; Parameters = @{ Guid = $plan.Guid }; Label = 'Usunięcie planu' })
        }
        'ApplySettingsButton' {
            $selection = @{}
            foreach ($setting in @($Entry.Power.Status.Settings | Where-Object { $_.Available })) {
                foreach ($source in 'Ac', 'Dc') {
                    $item = $p[$setting.Id + $source].SelectedItem
                    if ($null -ne $item) {
                        $selection['{0}|{1}' -f $setting.Id, $source.ToUpperInvariant()] = $item.Value
                    }
                }
            }
            if ($p['HibernateCheck'].IsEnabled -and $null -ne $p['HibernateCheck'].IsChecked) {
                $selection['Hibernate'] = [bool]$p['HibernateCheck'].IsChecked
            }
            if ($p['FastStartupCheck'].IsEnabled -and $null -ne $p['FastStartupCheck'].IsChecked) {
                $selection['FastStartup'] = [bool]$p['FastStartupCheck'].IsChecked
            }
            $steps = @(Get-MwpPowerChangeStep -Status $Entry.Power.Status -Selection $selection)
            $planName = if ($null -ne $Entry.Power.Status.ActivePlan) { $Entry.Power.Status.ActivePlan.Name } else { '(brak)' }
            Invoke-MwpUiInstanceChange -Entry $Entry -Header 'Zmiana ustawień zasilania' -Target ("Plan aktywny '{0}': {1} zmian(y)" -f $planName, $steps.Count) `
                -AfterCommand $after -Owner $Owner -Steps $steps
        }
        'ResetSettingsButton' {
            Update-MwpPowerView -Entry $Entry -Reset
        }
        'BatteryReportButton' {
            Start-MwpUiPowerReport -Entry $Entry -Kind Battery -Owner $Owner
        }
        'EnergyReportButton' {
            Start-MwpUiPowerReport -Entry $Entry -Kind Energy -Owner $Owner
        }
        'OpenReportButton' {
            if ($Entry.Power.LastReport) {
                $open = Open-MwpPowerReport -Path $Entry.Power.LastReport
                if (-not $open.Success) {
                    Show-MwpMessage -Text $open.Message -Kind Warning -Owner $Owner
                }
            }
        }
        'UndoButton' {
            $row = $p['UndoGrid'].SelectedItem
            if ($null -eq $row) { return }
            Invoke-MwpUiInstanceChange -Entry $Entry -Header 'Cofnięcie zmiany zasilania' -Target $row.Description -AfterCommand $after -Owner $Owner `
                -Steps @(@{ Command = 'Invoke-MwpUndo'; Parameters = @{ Id = $row.Id }; Label = 'Cofnięcie' })
        }
    }
}
