function Invoke-MwpAppsViewAction {
    <#
    .SYNOPSIS
        Obsługa przycisków widoku aplikacji: odczyt, profil użytkownika, odinstalowanie, aktualizacje, wyszukiwanie, instalacja i cofnięcie.

    .DESCRIPTION
        Zmiany idą przez Invoke-MwpUiInstanceChange z krokami — funkcjami MWP.Apps z kontekstem instancji
        (podgląd -WhatIf w tle, okno potwierdzenia z komputerem docelowym, wykonanie w tle, ponowny
        odczyt). Odinstalowanie to operacja destrukcyjna (okno ostrzegawcze; na komputerze zdalnym
        z wpisaniem nazwy komputera, D-050). Aktualizacja kilku pakietów = osobny krok na pakiet
        (postęp na pasku stanu, niepowodzenie jednego nie przerywa innych).

    .PARAMETER Action
        Nazwa przycisku (x:Name) z Views\Apps.xaml.
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
    $view = $Entry.Apps
    $context = $Entry.Instance.Context
    $computerName = $context.ComputerName
    $after = 'Start-MwpUiAppsRefresh'
    $row = $p['AppsGrid'].SelectedItem
    $app = if ($null -ne $row -and $null -ne $view.Inventory) { @($view.Inventory.Apps | Where-Object { $_.Id -eq [string]$row.Id }) | Select-Object -First 1 } else { $null }
    if (('AppsUninstallButton', 'AppsUpgradeButton') -contains $Action -and $null -eq $app) {
        Show-MwpMessage -Text 'Wybierz aplikację z listy.' -Owner $Owner
        return
    }

    switch ($Action) {
        'AppsRefreshButton' {
            Start-MwpUiAppsRefresh -Entry $Entry
        }
        'AppsProfileButton' {
            $selectedProfile = $p['AppsProfileBox'].SelectedItem
            $view.UserSid = if ($null -ne $selectedProfile -and $selectedProfile.Value) { @([string]$selectedProfile.Value) } else { @() }
            Start-MwpUiAppsRefresh -Entry $Entry -Kind Inventory
        }
        'UpgradesRefreshButton' {
            Start-MwpUiAppsRefresh -Entry $Entry -Kind Packages
        }
        'AppsUninstallButton' {
            $label = '{0}{1}' -f $app.Name, $(if ($app.Version) { ' ' + $app.Version } else { '' })
            $parameters = @{
                Entry        = $Entry
                Header       = 'Odinstalowanie aplikacji'
                Class        = 'Destructive'
                ConfirmText  = 'Odinstaluj'
                Target       = ('{0} — {1}' -f $label, $(if ($app.WingetId) { 'cofnięcie: ponowna instalacja z winget' } else { 'nie będzie można cofnąć' }))
                AfterCommand = $after
                Owner        = $Owner
                Steps        = @(@{ Command = 'Uninstall-MwpApp'; Parameters = @{ AppId = [string]$app.Id }; Label = ('Odinstalowanie: {0}' -f $app.Name) })
            }
            if ($context.Mode -ne 'Local') {
                $parameters['RequireText'] = $computerName
            }
            Invoke-MwpUiInstanceChange @parameters
        }
        'AppsUpgradeButton' {
            Invoke-MwpUiInstanceChange -Entry $Entry -Header 'Aktualizacja aplikacji (winget)' -Target ('{0}: {1} → {2}' -f $app.Name, $app.Version, $app.Available) `
                -ConfirmText 'Aktualizuj' -AfterCommand $after -Owner $Owner `
                -Steps @(@{ Command = 'Update-MwpWingetPackage'; Parameters = @{ Id = [string]$app.WingetId }; Label = ('Aktualizacja: {0}' -f $app.Name) })
        }
        'UpgradeSelectedButton' {
            $selected = @($p['UpgradesGrid'].SelectedItems | Where-Object { $null -ne $_ })
            if ($selected.Count -eq 0) {
                Show-MwpMessage -Text 'Zaznacz pakiety do aktualizacji.' -Owner $Owner
                return
            }
            $steps = @(foreach ($item in $selected) {
                    @{ Command = 'Update-MwpWingetPackage'; Parameters = @{ Id = [string]$item.Id }; Label = ('Aktualizacja: {0}' -f $item.Name) }
                })
            Invoke-MwpUiInstanceChange -Entry $Entry -Header 'Aktualizacja pakietów (winget)' -Target ('Pakiety: {0}' -f $selected.Count) -ConfirmText 'Aktualizuj' `
                -AfterCommand $after -Owner $Owner -Steps $steps
        }
        'SearchButton' {
            $query = ([string]$p['SearchBox'].Text).Trim()
            if (-not $query) {
                Show-MwpMessage -Text 'Wpisz nazwę lub identyfikator pakietu.' -Owner $Owner
                return
            }
            Start-MwpUiAppsRefresh -Entry $Entry -Kind Search -Query $query
        }
        'InstallButton' {
            $package = $p['SearchGrid'].SelectedItem
            if ($null -eq $package) {
                return
            }
            Invoke-MwpUiInstanceChange -Entry $Entry -Header 'Instalacja pakietu (winget)' -Target ('{0} ({1}) {2}' -f $package.Name, $package.Id, $package.Version) `
                -ConfirmText 'Zainstaluj' -AfterCommand $after -Owner $Owner `
                -Steps @(@{ Command = 'Install-MwpWingetPackage'; Parameters = @{ Id = [string]$package.Id }; Label = ('Instalacja: {0}' -f $package.Name) })
        }
        'AppsUndoButton' {
            $undo = $p['AppsUndoGrid'].SelectedItem
            if ($null -eq $undo) { return }
            Invoke-MwpUiInstanceChange -Entry $Entry -Header 'Cofnięcie zmiany aplikacji' -Target $undo.Description -AfterCommand $after -Owner $Owner `
                -Steps @(@{ Command = 'Invoke-MwpUndo'; Parameters = @{ Id = $undo.Id }; Label = 'Cofnięcie' })
        }
    }
}
