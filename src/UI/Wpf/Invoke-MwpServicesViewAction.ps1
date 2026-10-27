function Invoke-MwpServicesViewAction {
    <#
    .SYNOPSIS
        Obsługa przycisków widoku Usługi: odczyt, start/stop/restart, typ uruchomienia (podgląd, potwierdzenie, wykonanie w tle), profil, cofnięcie.

    .DESCRIPTION
        Zmiany idą przez Invoke-MwpUiInstanceChange z krokami — funkcjami MWP.Services z kontekstem
        instancji (D-044, D-045); podgląd zatrzymania wymienia usługi zależne. Profil: eksport
        ostatniego odczytu do pliku, wczytanie pliku i różnice z ostatnim odczytem
        (Compare-MwpServiceProfile -ServiceList, bez połączenia), zastosowanie różnic jako kroki
        Set-MwpServiceStartupType. Cofnięcie wywołuje Invoke-MwpUndo z kontekstem tej instancji.

    .PARAMETER Action
        Nazwa przycisku (x:Name) z Views\Services.xaml.
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
    $view = $Entry.Services
    $row = $p['ServicesGrid'].SelectedItem
    $service = if ($null -ne $row -and $view.ByName.ContainsKey([string]$row.Name)) { $view.ByName[[string]$row.Name] } else { $null }
    $after = 'Start-MwpUiServicesRefresh'
    $label = if ($null -ne $service) { "Usługa '{0}' ({1})" -f $service.DisplayName, $service.Name } else { '' }

    switch ($Action) {
        'ServicesRefreshButton' {
            Start-MwpUiServicesRefresh -Entry $Entry
        }
        'StartServiceButton' {
            if ($null -eq $service) { return }
            Invoke-MwpUiInstanceChange -Entry $Entry -Header 'Uruchomienie usługi' -Target $label -AfterCommand $after -Owner $Owner `
                -Steps @(@{ Command = 'Start-MwpService'; Parameters = @{ Name = $service.Name }; Label = 'Uruchomienie' })
        }
        'StopServiceButton' {
            if ($null -eq $service) { return }
            Invoke-MwpUiInstanceChange -Entry $Entry -Header 'Zatrzymanie usługi' -Target $label -AfterCommand $after -Owner $Owner `
                -Steps @(@{ Command = 'Stop-MwpService'; Parameters = @{ Name = $service.Name }; Label = 'Zatrzymanie' })
        }
        'RestartServiceButton' {
            if ($null -eq $service) { return }
            Invoke-MwpUiInstanceChange -Entry $Entry -Header 'Ponowne uruchomienie usługi' -Target $label -AfterCommand $after -Owner $Owner `
                -Steps @(@{ Command = 'Restart-MwpService'; Parameters = @{ Name = $service.Name }; Label = 'Ponowne uruchomienie' })
        }
        'SetStartupTypeButton' {
            $wanted = $p['StartupTypeBox'].SelectedItem
            if ($null -eq $service -or $null -eq $wanted) { return }
            Invoke-MwpUiInstanceChange -Entry $Entry -Header 'Zmiana typu uruchomienia usługi' -Target $label -AfterCommand $after -Owner $Owner `
                -Steps @(@{ Command = 'Set-MwpServiceStartupType'; Parameters = @{ Name = $service.Name; StartupType = $wanted.Value }; Label = ('Typ: {0}' -f $wanted.Label) })
        }
        'ExportProfileButton' {
            if ($null -eq $view.List) { return }
            $dialog = New-Object -TypeName Microsoft.Win32.SaveFileDialog
            $dialog.Title = 'Eksport profilu usług'
            $dialog.Filter = 'Profil usług (*.json)|*.json'
            $dialog.FileName = 'uslugi-{0}-{1:yyyyMMdd-HHmm}.json' -f ([string]$Entry.Instance.Context.ComputerName -replace '[^A-Za-z0-9_.-]', '_'), (Get-Date)
            $dialog.OverwritePrompt = $true
            $accepted = if ($null -ne $Owner) { $dialog.ShowDialog($Owner) } else { $dialog.ShowDialog() }
            if (-not $accepted) { return }
            $result = Export-MwpServiceProfile -Path $dialog.FileName -ServiceList $view.List -Confirm:$false
            Show-MwpMessage -Text $result.Message -Kind $(if ($result.Success) { 'Info' } else { 'Warning' }) -Owner $Owner
        }
        'LoadProfileButton' {
            if ($null -eq $view.List) { return }
            $dialog = New-Object -TypeName Microsoft.Win32.OpenFileDialog
            $dialog.Title = 'Wczytaj profil usług'
            $dialog.Filter = 'Profil usług (*.json)|*.json|Wszystkie pliki (*.*)|*.*'
            $accepted = if ($null -ne $Owner) { $dialog.ShowDialog($Owner) } else { $dialog.ShowDialog() }
            if (-not $accepted) { return }
            $read = Read-MwpServiceProfile -Path $dialog.FileName
            if (-not $read.Success) {
                Show-MwpMessage -Text $read.Message -Kind Warning -Owner $Owner
                return
            }
            $compare = Compare-MwpServiceProfile -ProfileData $read.Data -ServiceList $view.List
            $view.Profile = $read.Data
            $view.Diff = $(if ($compare.Success) { @($compare.Data) } else { @() })
            $text = '{0} {1}' -f $read.Message, $compare.Message
            if (@($read.Data.Warnings).Count -gt 0) {
                $text = '{0} Pominięte pozycje: {1}' -f $text, (@($read.Data.Warnings) -join ' ')
            }
            $p['ProfileText'].Text = $text
            Update-MwpServicesView -Entry $Entry
        }
        { $_ -in 'ApplyProfileButton', 'ApplySelectedProfileButton' } {
            $rows = if ($Action -eq 'ApplyProfileButton') { @($view.Diff) } else { @($p['ProfileGrid'].SelectedItems) }
            $steps = @(Get-MwpServiceProfileStep -Row $rows)
            $source = if ($null -ne $view.Profile) { '{0} (komputer źródłowy: {1})' -f $view.Profile.Path, $view.Profile.ComputerName } else { 'profil usług' }
            Invoke-MwpUiInstanceChange -Entry $Entry -Header 'Import profilu usług' -Target ('{0}: {1} zmian(y) typu uruchomienia' -f $source, $steps.Count) `
                -AfterCommand $after -Owner $Owner -Steps $steps
        }
        'ServicesUndoButton' {
            $undo = $p['ServicesUndoGrid'].SelectedItem
            if ($null -eq $undo) { return }
            Invoke-MwpUiInstanceChange -Entry $Entry -Header 'Cofnięcie zmiany usługi' -Target $undo.Description -AfterCommand $after -Owner $Owner `
                -Steps @(@{ Command = 'Invoke-MwpUndo'; Parameters = @{ Id = $undo.Id }; Label = 'Cofnięcie' })
        }
    }
}
