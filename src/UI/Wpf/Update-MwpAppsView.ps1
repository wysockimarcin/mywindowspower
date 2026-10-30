function Update-MwpAppsView {
    <#
    .SYNOPSIS
        Odświeża widok aplikacji: stan i ostrzeżenia, listę programów z filtrem, aktualizacje winget, wyniki wyszukiwania, cofnięcia, szczegóły i dostępność przycisków.

    .DESCRIPTION
        Z -StateOnly (zegar okna) zmienia tylko przyciski; z -Selection — szczegóły zaznaczonej
        aplikacji i przyciski; z -Filter — tylko listę programów (filtry bez ponownego odczytu).
        Zaznaczenie programu zostaje po odświeżeniu (po identyfikatorze). Reguły dostępności:
        Get-MwpAppsActionState.

    .PARAMETER StateOnly
        Tylko przyciski.

    .PARAMETER Selection
        Szczegóły po zmianie zaznaczenia.

    .PARAMETER Filter
        Lista programów po zmianie filtru.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Zmienia tylko kontrolki okna.')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable] $Entry,

        [switch] $StateOnly,

        [switch] $Selection,

        [switch] $Filter
    )

    $p = $Entry.ModuleView.Controls
    $view = $Entry.Apps
    $inventory = $view.Inventory
    $packages = $view.Packages
    $context = $Entry.Instance.Context
    $remote = $context.Mode -ne 'Local'
    $connected = -not (Get-MwpConnectionStateInfo -Context $context).NeedsCredential
    $grid = $p['AppsGrid']
    $full = -not $StateOnly -and -not $Selection -and -not $Filter

    if ($full) {
        $p['AppsStatusText'].Text = if ($view.InventoryLoading) {
            'Odczyt programów komputera {0}…' -f (Format-MwpTargetLabel -Context $context)
        }
        elseif ($null -ne $inventory) {
            'Komputer {0} · {1} pozycji (z ukrytymi) · odczyt {2}{3}' -f (Format-MwpTargetLabel -Context $context), @($inventory.Apps).Count,
            $(if ($null -ne $view.InventoryReadAt) { ([datetime]$view.InventoryReadAt).ToString('HH:mm:ss') } else { '' }),
            $(if ($view.PackagesLoading) { ' · sprawdzanie winget…' } else { '' })
        }
        else {
            'Brak odczytu listy programów.'
        }
        $warnings = New-Object -TypeName System.Collections.Generic.List[string]
        if ($view.InventoryError) { $warnings.Add([string]$view.InventoryError) }
        if ($view.PackagesError) { $warnings.Add(('winget: {0}' -f $view.PackagesError)) }
        if ($null -ne $inventory) {
            foreach ($warning in @($inventory.Warnings)) { $warnings.Add([string]$warning) }
            if ($remote -and -not $inventory.IsAdministrator) {
                $warnings.Add('Konto połączenia nie ma uprawnień administratora na tym komputerze: lista działa, zmiany są niedostępne.')
            }
        }
        if ($null -ne $packages) {
            foreach ($warning in @($packages.Warnings)) { $warnings.Add(('winget: {0}' -f $warning)) }
        }
        if ($remote) {
            $warnings.Add(('Komputer zdalny: pakiety Appx dotyczą konta połączenia ({0}).' -f $(if ($null -ne $inventory) { $inventory.CurrentUser } else { $context.Identity.UserName })))
        }
        $p['AppsWarningText'].Text = $warnings -join [Environment]::NewLine
        $p['AppsWarningBanner'].Visibility = $(if ($warnings.Count -gt 0) { 'Visible' } else { 'Collapsed' })
        $p['AppsContextText'].Text = Get-MwpAppsContextText -Remote $remote -Packages $packages

        # Profile użytkowników (localhost i komputer zdalny, D-051): wybór zalogowanego profilu do odczytu jego programów i pakietów.
        $p['AppsProfilePanel'].Visibility = $(if ($null -ne $inventory) { 'Visible' } else { 'Collapsed' })
        $selectedSid = [string](@($view.UserSid) | Select-Object -First 1)
        $options = @(Get-MwpAppsTargetOption -Kind Profile -Inventory $inventory -Remote $remote)
        $p['AppsProfileBox'].ItemsSource = $options
        $p['AppsProfileBox'].SelectedItem = @($options | Where-Object { $_.Value -eq $selectedSid }) | Select-Object -First 1
        $installSid = if ($null -ne $p['InstallTargetBox'].SelectedItem) { [string]$p['InstallTargetBox'].SelectedItem.Value } else { '' }
        $targets = @(Get-MwpAppsTargetOption -Kind Install -Inventory $inventory -Remote $remote)
        $p['InstallTargetBox'].ItemsSource = $targets
        $again = @($targets | Where-Object { $_.Value -eq $installSid }) | Select-Object -First 1
        $p['InstallTargetBox'].SelectedItem = $(if ($null -ne $again) { $again } else { $targets[0] })

        $p['UpgradesText'].Text = if ($view.PackagesLoading) {
            'Sprawdzanie pakietów winget na komputerze {0}…' -f (Format-MwpTargetLabel -Context $context)
        }
        elseif ($view.PackagesError) {
            [string]$view.PackagesError
        }
        elseif ($null -ne $packages) {
            'Pakietów z dostępną aktualizacją: {0} (z {1} rozpoznanych przez winget).' -f @($packages.Packages | Where-Object { $_.HasUpgrade }).Count, @($packages.Packages).Count
        }
        else {
            ''
        }
        $upgrades = if ($null -ne $packages) { [pscustomobject]@{ Packages = @($packages.Packages | Where-Object { $_.HasUpgrade }) } } else { $null }
        $p['UpgradesGrid'].ItemsSource = @(Get-MwpAppsRow -Package $upgrades)

        $p['SearchText'].Text = if ($view.SearchLoading) {
            'Wyszukiwanie „{0}”…' -f $view.SearchQuery
        }
        elseif ($view.SearchError) {
            [string]$view.SearchError
        }
        elseif ($null -ne $view.Search) {
            'Wyniki dla „{0}”: {1}.' -f $view.SearchQuery, @($view.Search.Packages).Count
        }
        else {
            ''
        }
        $p['SearchGrid'].ItemsSource = @(Get-MwpAppsRow -Package $view.Search -Installed $packages)

        $undoRows = @(Get-MwpUndoEntry -ComputerName $context.ComputerName -Status Pending | Where-Object { $_.Module -eq 'MWP.Apps' } |
                Sort-Object -Property CreatedAt -Descending | Select-Object -First 50 | ForEach-Object {
                    [pscustomobject]@{ Id = $_.Id; When = $(if ($_.CreatedAt) { ([datetime]$_.CreatedAt).ToString('yyyy-MM-dd HH:mm') } else { '' }); Description = $_.Description }
                })
        $p['AppsUndoGrid'].ItemsSource = $undoRows
        $Filter = $true
    }

    if ($Filter) {
        $selectedId = if ($null -ne $grid.SelectedItem) { [string]$grid.SelectedItem.Id } else { '' }
        $source = $p['AppsSourceBox'].SelectedItem
        $scope = $p['AppsScopeBox'].SelectedItem
        $rows = @(Get-MwpAppsRow -Inventory $inventory -Filter @{
                Search                 = [string]$p['AppsSearchBox'].Text
                Source                 = $(if ($null -ne $source) { [string]$source.Value } else { 'All' })
                Scope                  = $(if ($null -ne $scope) { [string]$scope.Value } else { 'All' })
                IncludeSystemComponent = [bool]$p['AppsSystemCheck'].IsChecked
                UpgradeOnly            = [bool]$p['AppsUpgradeCheck'].IsChecked
            })
        $grid.ItemsSource = $rows
        $again = @($rows | Where-Object { $_.Id -eq $selectedId }) | Select-Object -First 1
        $grid.SelectedItem = $again
        $p['AppsCountText'].Text = if ($null -ne $inventory) { 'Pokazano {0} z {1}. Kliknij nagłówek kolumny, żeby posortować.' -f $rows.Count, @($inventory.Apps).Count } else { '' }
        $Selection = $true
    }

    $appId = if ($null -ne $grid.SelectedItem) { [string]$grid.SelectedItem.Id } else { '' }
    $ready = $connected -and $Entry.Busy -eq 0 -and -not $view.InventoryLoading
    $wingetOk = $null -ne $packages -and [bool]$packages.Success
    $state = Get-MwpAppsActionState -Inventory $inventory -AppId $appId -WingetAvailable $wingetOk -Packages $packages -Remote $remote -Ready $ready `
        -SelectedUpgrades @($p['UpgradesGrid'].SelectedItems).Count -SearchSelected ($null -ne $p['SearchGrid'].SelectedItem)
    if ($Selection) {
        $detail = Get-MwpAppsDetail -App $state.App
        $p['AppsDetailTitle'].Text = $detail.Title
        $p['AppsDetailText'].Text = $detail.Text
    }
    $p['AppsActionText'].Text = $state.Hint
    $p['AppsRefreshButton'].IsEnabled = $connected -and -not $view.InventoryLoading -and -not $view.PackagesLoading
    $p['AppsProfileButton'].IsEnabled = $connected -and -not $view.InventoryLoading
    $p['AppsUninstallButton'].IsEnabled = $state.CanUninstall
    $p['AppsUpgradeButton'].IsEnabled = $state.CanUpgradeApp -and -not $view.PackagesLoading
    $p['UpgradesRefreshButton'].IsEnabled = $connected -and -not $view.PackagesLoading
    $p['UpgradeSelectedButton'].IsEnabled = $state.CanUpgrade -and -not $view.PackagesLoading
    $p['SearchButton'].IsEnabled = $state.CanSearch -and -not $view.SearchLoading
    $p['InstallButton'].IsEnabled = $state.CanInstall -and -not $view.SearchLoading
    $p['AppsUndoButton'].IsEnabled = $ready -and $null -ne $p['AppsUndoGrid'].SelectedItem
}
